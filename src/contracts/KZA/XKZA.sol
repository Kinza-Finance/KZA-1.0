// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/access/Ownable.sol";
import "@openzeppelin/token/ERC20/ERC20.sol";
import "@openzeppelin/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/security/ReentrancyGuard.sol";
import "@openzeppelin/utils/math/SafeMath.sol";
import "@openzeppelin/utils/structs/EnumerableSet.sol";
import "@openzeppelin/utils/Address.sol";

import "../../interfaces/IKZA.sol";
import "../../interfaces/IVoter.sol";

// | |/ /_ _| \ | |__  /  / \   
// | ' / | ||  \| | / /  / _ \  
// | . \ | || |\  |/ /_ / ___ \ 
// |_|\_\___|_| \_/____/_/   \_\


/// @notice XKZA - Kinza protocol voting token
/// @title XKZA
/// @notice xKZA is Kinza's escrowed governance token obtainable by converting KZA
///         It's non-transferable, except from/to whitelisted addresses
///         It can be redeemed back to KZA by going through a vesting process
///         XKZA in vesting process would have a discounted voting power,
///         defined in VoteLogic.
contract XKZA is Ownable, ReentrancyGuard, ERC20("escrowed Kinza Token", "xKZA") {
    using Address for address;
    using SafeMath for uint256;
    using EnumerableSet for EnumerableSet.AddressSet;
    using SafeERC20 for IKZA;

    /*//////////////////////////////////////////////////////////////
                      CONSTANTS & IMMUTABLES
    //////////////////////////////////////////////////////////////*/
    IKZA public immutable KZA; // token to convert to/from

    /*//////////////////////////////////////////////////////////////
                    STORAGE VARIABLES & TYPES
    //////////////////////////////////////////////////////////////*/
    struct RedeemInfo {
        uint256 amount; //  amount to receive when vesting has ended
        uint256 xAmount; // xToken amount to redeem
        uint256 endTime;
    }

    // Redeeming min/max settings
    uint256 public minRedeemRatio = 50; // 1:0.5
    uint256 public maxRedeemRatio = 100; // 1:1
    uint256 public minRedeemDuration = 15 days; // 1296000s
    uint256 public maxRedeemDuration = 90 days; // 7776000s

    EnumerableSet.AddressSet private _transferWhitelist; // addresses allowed to send/receive xKZA

    mapping(address => RedeemInfo[]) public userRedeems; // User's redeeming instances
    mapping(address => uint256) public userReedemTotal; // User's redeeming total

    IVoter public voter;// voter

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/
    event Convert(
        address indexed from, 
        address to, uint256 amount
    );
                  
    event UpdateRedeemSettings(
        uint256 minRedeemRatio, 
        uint256 maxRedeemRatio, 
        uint256 minRedeemDuration, 
        uint256 maxRedeemDuration
    );

    event SetTransferWhitelist(
        address account, 
        bool add
    );

    event Redeem(
        address indexed userAddress, 
        uint256 xAmount, 
        uint256 amount, 
        uint256 duration
    );

    event FinalizeRedeem(
        address indexed userAddress, 
        uint256 xAmount, 
        uint256 amount
    );

    event CancelRedeem(
        address indexed userAddress, 
        uint256 xAmount
      );

    event NewVoter(address newVoter);

    /*//////////////////////////////////////////////////////////////
                          CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor(address _KZA, address _governance) {
      KZA = IKZA(_KZA);
      _transferWhitelist.add(address(this));
      transferOwnership(_governance);
    }

    /// @notice check if a redeem index exists
    /// @param _userAddress the user address to check
    /// @param _redeemIndex the index to check
    modifier validateRedeem(address _userAddress, uint256 _redeemIndex) {
      require(_redeemIndex < userRedeems[_userAddress].length, "validateRedeem: redeem entry does not exist");
      _;
    }

    /*//////////////////////////////////////////////////////////////
                            GETTERS
    //////////////////////////////////////////////////////////////*/

    /// @param _amount the amount of xToken
    /// @param _duration the duration of vest passed
    /// @return redeemable KZA for "amount" of xKZA vested for "duration" seconds
    function getKZAByVestingDuration(uint256 _amount, uint256 _duration) public view returns (uint256) {
      if(_duration < minRedeemDuration) {
        return 0;
      }

      // capped to maxRedeemDuration
      if (_duration > maxRedeemDuration) {
        return _amount.mul(maxRedeemRatio).div(100);
      }

      uint256 ratio = minRedeemRatio.add(
        (_duration.sub(minRedeemDuration)).mul(maxRedeemRatio.sub(minRedeemRatio))
        .div(maxRedeemDuration.sub(minRedeemDuration))
      );

      return _amount.mul(ratio).div(100);
    }

    /// @param _userAddress user address
    /// @return number of "userAddress" pending redeems
    function getUserRedeemsLength(address _userAddress) external view returns (uint256) {
      return userRedeems[_userAddress].length;
    }


    /// @param _userAddress user address
    /// @param _redeemIndex user redeem index
    /// @return amount, xAmount and endTime of a redeem position
    function getUserRedeem(address _userAddress, uint256 _redeemIndex) external view validateRedeem(_userAddress, _redeemIndex) returns (uint256, uint256, uint256) {
      RedeemInfo storage _redeem = userRedeems[_userAddress][_redeemIndex];
      return (_redeem.amount, _redeem.xAmount, _redeem.endTime);
    }

    /// @return length of transferWhitelist array
    function transferWhitelistLength() external view returns (uint256) {
      return _transferWhitelist.length();
    }
    /// @param _index index of the whitelist
    /// @dev returns transferWhitelist array item's address for "index"
    /// @return whitelisted address at the index of transferWhitelist
    function transferWhitelist(uint256 _index) external view returns (address) {
      return _transferWhitelist.at(_index);
    }

    /// @param _account user address
    /// @return if "account" is allowed to send/receive xKZA
    function isTransferWhitelisted(address _account) external view returns (bool) {
      return _transferWhitelist.contains(_account);
    }

    /*//////////////////////////////////////////////////////////////
                         OWNABLE FUNCTION
    //////////////////////////////////////////////////////////////*/

    /// @param _newVoter new voter contract
    function updateVoter(address _newVoter) external onlyOwner {
      voter = IVoter(_newVoter);
      emit NewVoter(_newVoter);
    }

    /// @param _minRedeemRatio min redeem ratio
    /// @param _maxRedeemRatio max redeem ratio
    /// @param _minRedeemDuration min redeem duration
    /// @param _maxRedeemDuration min redeem duration
    function updateRedeemSettings(uint256 _minRedeemRatio, uint256 _maxRedeemRatio, uint256 _minRedeemDuration, uint256 _maxRedeemDuration) external onlyOwner {
      require(_minRedeemRatio <= _maxRedeemRatio, "updateRedeemSettings: wrong ratio values");
      require(_minRedeemDuration < _maxRedeemDuration, "updateRedeemSettings: wrong duration values");
      // should never exceed 100%
      require(_maxRedeemRatio <= 100, "updateRedeemSettings: max redeem ratio exceeds");

      minRedeemRatio = _minRedeemRatio;
      maxRedeemRatio = _maxRedeemRatio;
      minRedeemDuration = _minRedeemDuration;
      maxRedeemDuration = _maxRedeemDuration;

      emit UpdateRedeemSettings(_minRedeemRatio, _maxRedeemRatio, _minRedeemDuration, _maxRedeemDuration);
    }

    /// @notice Adds or removes addresses from the transferWhitelist
    /// @param _account address to be added to the whitelist
    /// @param _add add/remove flag
    function updateTransferWhitelist(address _account, bool _add) external onlyOwner {
      require(_account != address(this), "updateTransferWhitelist: Cannot remove xToken from whitelist");

      if(_add) _transferWhitelist.add(_account);
      else _transferWhitelist.remove(_account);

      emit SetTransferWhitelist(_account, _add);
    }

    /*//////////////////////////////////////////////////////////////
                         CONVERT/REDEEM LOGIC
    //////////////////////////////////////////////////////////////*/

    /// @notice user would receive 1:1 of xKZA 
    /// @param _amount amount of KZA token to convert into xKZA
    function convert(uint256 _amount) external nonReentrant {
      _convert(_amount, msg.sender);
      // update vote base on the latest xKZA balance, this improve UX
      voter.reVote(msg.sender);
    }

    /// @notice an entry point for a smart contract to convert caller's "amount" 
    ///         of KZA to xKZA to "to" address
    /// @param _amount amount of KZA token to convert into xKZA
    /// @param _to receiver of the non-transferrable xKZA
    function convertTo(uint256 _amount, address _to) external nonReentrant {
      require(address(msg.sender).isContract(), "convertTo: not allowed for EOA");
      _convert(_amount, _to);
      // update vote base on the latest xKZA balance, this improve UX
      voter.reVote(_to);
    }


    /// @notice Initiates redeem process from xKZA to KZA
    ///         the final KZA received may have discount depending on duration
    /// @param _xAmount amount of xKZA token to redeem back to KZA
    /// @param _duration the intended length of vesting
    function redeem(uint256 _xAmount, uint256 _duration) external nonReentrant {
      require(_xAmount > 0, "redeem: xAmount cannot be null");
      require(_duration >= minRedeemDuration, "redeem: duration too low");

      _transfer(msg.sender, address(this), _xAmount);

      // get corresponding KZA amount
      uint256 amount = getKZAByVestingDuration(_xAmount, _duration);
      emit Redeem(msg.sender, _xAmount, amount, _duration);

      userReedemTotal[msg.sender] += _xAmount;
      // add redeeming entry
      userRedeems[msg.sender].push(RedeemInfo(amount, _xAmount, _currentBlockTimestamp().add(_duration)));

      // reflect the latest vote balance impacted by the redeem operation.
      if (address(voter) != address(0)) {
        uint256 before = KZA.balanceOf(address(this));
        
        voter.reVote(msg.sender);
        // a sanity check to make sure the token balance on this contract remain the same
        require(before == KZA.balanceOf(address(this)), "voter creates difference in locked token");
      }
    }


    /// @notice finalize a redemption operation by transferring the KZA back
    ///         after the vesting duration has been reached
    /// @param redeemIndex the redeem index that user would like to finalize
    function finalizeRedeem(uint256 redeemIndex) external nonReentrant validateRedeem(msg.sender, redeemIndex) {
      RedeemInfo storage _redeem = userRedeems[msg.sender][redeemIndex];
      require(_currentBlockTimestamp() >= _redeem.endTime, "finalizeRedeem: vesting duration has not ended yet");

      // remove from SBT total
      userReedemTotal[msg.sender] -= _redeem.xAmount;
      _finalizeRedeem(msg.sender, _redeem.xAmount, _redeem.amount);

      // remove redeem entry
      _deleteRedeemEntry(redeemIndex);
      if (address(voter) != address(0)) {
        uint256 before = KZA.balanceOf(address(this));
        
        voter.reVote(msg.sender);
        // a sanity check to make sure the token balance on this contract remain the same
        require(before == KZA.balanceOf(address(this)), "voter creates difference in locked token");
      }
    }

    /// @notice Cancels an ongoing/finished redeem entry
    /// @param redeemIndex the redeem index that user would like to cancel
    function cancelRedeem(uint256 redeemIndex) external nonReentrant validateRedeem(msg.sender, redeemIndex) {
      RedeemInfo storage _redeem = userRedeems[msg.sender][redeemIndex];

      // make redeeming xKZA available again
      userReedemTotal[msg.sender] -= _redeem.xAmount;
      _transfer(address(this), msg.sender, _redeem.xAmount);

      if (address(voter) != address(0)) {
        uint256 before = KZA.balanceOf(address(this));
        
        voter.reVote(msg.sender);
        // a sanity check to make sure the token balance on this contract remain the same
        require(before == KZA.balanceOf(address(this)), "voter creates difference in locked token");
      }

      emit CancelRedeem(msg.sender, _redeem.xAmount);

      // remove redeem entry
      _deleteRedeemEntry(redeemIndex);
    }

    /*//////////////////////////////////////////////////////////////
                         INTERNAL FUNCTION
    //////////////////////////////////////////////////////////////*/

    /// @notice user would receive 1:1 of xKZA 
    /// @param _amount amount of KZA token to convert into xKZA
    /// @param _to amount of KZA token to convert into xKZA
    function _convert(uint256 _amount, address _to) internal {
      require(_amount != 0, "convert: amount cannot be null");

      KZA.safeTransferFrom(msg.sender, address(this), _amount);
      // mint new xToken
      _mint(_to, _amount);

      emit Convert(msg.sender, _to, _amount);
      
    }

    /**
    * @dev Finalizes the redeeming process for "userAddress" by transferring him "amount" and removing "xAmount" from supply
    *
    * Any vesting check should be ran before calling this
    * KZA excess is automatically burnt
    */
    /// @notice finalize a redemption operation by transferring the KZA back
    ///         after the vesting duration has been reached
    /// @dev    Any vesting check should be ran before calling this
    ///         KZA excess is automatically burnt
    /// @param _userAddress userAddress to receive KZA
    /// @param _xAmount the amount of xKZA to burn
    /// @param _amount the _amount of KZA to return
    function _finalizeRedeem(address _userAddress, uint256 _xAmount, uint256 _amount) internal {
      uint256 excess = _xAmount.sub(_amount);

      // sends due KZA tokens
      KZA.safeTransfer(_userAddress, _amount);

      // burns KZA excess if any
      KZA.burn(excess);
      _burn(address(this), _xAmount);

      emit FinalizeRedeem(_userAddress, _xAmount, _amount);
    }

    /// @dev poping the last entry after swapping the last entry with the one to delete
    /// @param _index index of redeem entry to delete
    function _deleteRedeemEntry(uint256 _index) internal {
      userRedeems[msg.sender][_index] = userRedeems[msg.sender][userRedeems[msg.sender].length - 1];
      userRedeems[msg.sender].pop();
    }

    /// @notice Hook override to forbid transfers except from whitelisted addresses and minting
    /// @param _from sender of the transfer
    /// @param _to receiver of the transfer
    function _beforeTokenTransfer(address _from, address _to, uint256 /*amount*/) internal view override {
      require(_from == address(0) || _transferWhitelist.contains(_from) || _transferWhitelist.contains(_to), "xToken does not allow transfer");
    }

    /// @dev Utility function to get the current block timestamp
    function _currentBlockTimestamp() internal view virtual returns (uint256) {
      /* solhint-disable not-rely-on-time */
      return block.timestamp;
    }

}