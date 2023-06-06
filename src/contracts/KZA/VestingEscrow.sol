// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/access/Ownable.sol";

import "../../interfaces/IKZA.sol";

import '../../libraries/UtilLib.sol';
// | |/ /_ _| \ | |__  /  / \   
// | ' / | ||  \| | / /  / _ \  
// | . \ | || |\  |/ /_ / ___ \ 
// |_|\_\___|_| \_/____/_/   \_\

/// @notice KZA - Kinza protocol vesting contract
/// @title VestingEscrow
/// @notice distribute the initial 40M KZA through various vesting schemes
///         each address can only have 1 vesting position
contract VestingEscrow is Ownable {
    using SafeERC20 for IKZA;

    /*//////////////////////////////////////////////////////////////
                      CONSTANTS & IMMUTABLES
    //////////////////////////////////////////////////////////////*/
    uint256 public constant CLIFF = 365 days;
    uint256 public constant VESTING_PERIOD = 730 days;

    uint256 public constant RESERVE_CLIFF = 0 days;
    uint256 public constant RESERVE_VESTING_PERIOD = 1460 days;

    IKZA public immutable KZA;

    // The total Distributable is 40m
    uint256 public constant TOTAL_AVAIALBLE = 40_000_000 * 1e18;

    /*//////////////////////////////////////////////////////////////
                        STORAGE VARIABLES  & TYPES
    //////////////////////////////////////////////////////////////*/

    uint256 public distributed;

    mapping(address => AccountInfo) public accountInfos;
    mapping(address => uint256) public withdrawals;

    address[] public vesters;
    uint256 public claimedFromRemovedVesters;

    struct AccountInfo {
        uint256 total;
        uint256 startTime;
        uint256 vestingPeriod;
    }

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/
    event LogVest(
        address indexed user, 
        uint256 amount, 
        uint256 period, 
        uint256 startTime
    );

    event LogRemoveVest(address indexed user);

    event LogUpdateVest(address indexed user);

    event Claimed(
        address user, 
        address to, 
        uint256 amount
    );
    
    /*//////////////////////////////////////////////////////////////
                          CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor(address _kza, address _gov) {
        UtilLib.checkNonZeroAddress(_kza);
        UtilLib.checkNonZeroAddress(_gov);
        KZA = IKZA(_kza);
        transferOwnership(_gov);
    }

    /// @param _vester the receiver of the vesting position
    /// @param _amount the amount of token 
    function addVesting(address _vester, uint256 _amount) external onlyOwner {
        AccountInfo memory info = accountInfos[_vester];
        require(info.total == 0, "position exists");
        _addVesting(_vester, _amount, VESTING_PERIOD, CLIFF);
    }

    /// @param _vester the receiver of the vesting position
    /// @param _amount the amount of token 
    function addReserveVesting(address _vester, uint256 _amount) external onlyOwner {
        AccountInfo memory info = accountInfos[_vester];
        require(info.total == 0, "position exists");
        _addVesting(_vester, _amount, RESERVE_VESTING_PERIOD, RESERVE_CLIFF);
    }

    /// @notice Vester once added, would leave a permanent record on vesters, to track the total vested
    /// @param _vester the receiver of the vesting position
    /// @param _amount the amount of token 
    /// @param _vestingPeriod the duration of linear vesting
    /// @param _cliff the duration before vesting kicks in
    function _addVesting(address _vester, uint256 _amount, uint256 _vestingPeriod, uint256 _cliff) internal {
        require(distributed + _amount <= TOTAL_AVAIALBLE, "not enough allocation");
        require(_amount > 0, "allocation is 0");
        distributed += _amount;
        accountInfos[_vester] = AccountInfo({
            total: _amount, 
            startTime: _cliff + block.timestamp, 
            vestingPeriod: _vestingPeriod
            });
        vesters.push(_vester);
        emit LogVest(_vester, _amount, _vestingPeriod, _cliff + block.timestamp);
    }

    /// @notice remove the vester, account whatever that is already claimed
    /// @param _vester the vester to remove the vesting position from
    function removeVesting(address _vester) external onlyOwner {
        AccountInfo memory info = accountInfos[_vester];
        uint256 claimed = withdrawals[_vester];
        require(info.total != 0, "non existent vesting position");
        
        delete accountInfos[_vester];
        withdrawals[_vester] = 0;

        distributed -= info.total;
        distributed += claimed;
        claimedFromRemovedVesters += claimed;

        emit LogRemoveVest(_vester);
    }

    /// @notice update the vester with the new parameters 
    /// @dev there are some constraint: 
    ///      1.) new amonunt has to be bigger than claimed amount
    ///      2.) the updated amount also fits into the TOTAL_AVAILABLE
    /// @param _vester the receiver of the vesting position
    /// @param _amount the amount of token 
    /// @param _vestingPeriod the duration of linear vesting
    /// @param _cliff the duration before vesting kicks in
    function updateVesting(address _vester, uint256 _amount, uint256 _vestingPeriod, uint256 _cliff) external onlyOwner {
        AccountInfo memory info = accountInfos[_vester];
        require(info.total != 0, "non existent vesting position");
        uint256 claimed = withdrawals[_vester];
        require(_amount > claimed, "already over-claimed");
        require(distributed + _amount - info.total <= TOTAL_AVAIALBLE, "not enough allocation");
        // offset the old position
        distributed -= info.total;
        // reset for the new postion
        distributed += _amount;
        accountInfos[_vester] = AccountInfo({
            total: _amount, 
            startTime: _cliff + block.timestamp, 
            vestingPeriod: _vestingPeriod
            });
        emit LogUpdateVest(_vester);
    }

    /// @notice entry point to get claimable
    /// @param _amount amount of liquid token to claim
    function claim(uint256 _amount) external {
        _claim(msg.sender, msg.sender, _amount);
        
    }

    /// @notice entry point to get claimable for a receiver
    /// @param _to receiver
    /// @param _amount amount of liquid token to claim
    function claimTo(address _to, uint256 _amount) external {
        _claim(msg.sender, _to, _amount);
    }
    

    /// @notice Get total amount of kza claimed by user
    /// @param _vester Target vester
    /// @return the total withdrawan
    function totalWithdrawn(address _vester) external view returns (uint256) {
        return withdrawals[_vester];
    }


    /// @notice Get total amount of kza claimed by user
    /// @param _vester Target vester
    /// @return info of the vester
    function getAccountInfo(address _vester) public view returns (AccountInfo memory info) {
        return accountInfos[_vester];
    }

    /// @notice View the total liquid token, including claimed and not claimed
    /// @return currentLiquid returns the total liquid token released
    function viewGlobalLiquid() public view returns(uint256 currentLiquid) {
        uint256 length = vesters.length;
        if (length == 0) return 0;

        AccountInfo memory info;
        for (uint256 i = 0; i < length; i++) {
            info = getAccountInfo(vesters[i]);
            if (block.timestamp > info.startTime) {
                uint256 timeDelta = 
                block.timestamp - info.startTime > info.vestingPeriod
                ? info.vestingPeriod
                : block.timestamp - info.startTime;

                uint256 claimable = info.total * timeDelta / info.vestingPeriod;

                currentLiquid += claimable;
            }
            
        } 
        currentLiquid += claimedFromRemovedVesters;
    }
    /*//////////////////////////////////////////////////////////////
                         INTERNAL FUNCTION
    //////////////////////////////////////////////////////////////*/

    /// @notice internal function
    /// @param _vester vester
    /// @param _to receiver
    /// @param _amount amount of liquid token to claim
    function _claim(address _vester, address _to, uint256 _amount) internal {
        AccountInfo memory info = accountInfos[_vester];
        require(info.total != 0, "There is no active position");
        require(block.timestamp > info.startTime, "vesting starts in future");
        uint256 timeDelta = 
            block.timestamp - info.startTime > info.vestingPeriod
            ? info.vestingPeriod
            : block.timestamp - info.startTime;
        uint256 claimable = info.total * timeDelta / info.vestingPeriod;
        uint256 claimed = withdrawals[_vester];
        if ((claimable - claimed) < _amount) {
            _amount = claimable - claimed;
        }
        withdrawals[_vester] += _amount;
        KZA.safeTransfer(_to, _amount);
        emit Claimed(_vester, _to, _amount);
    }
}