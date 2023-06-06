
// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/access/Ownable.sol";
import '../../interfaces/IVoteLogic.sol';
import '../../interfaces/IBribe.sol';
import './AggregateBribe.sol';

// | |/ /_ _| \ | |__  /  / \   
// | ' / | ||  \| | / /  / _ \  
// | . \ | || |\  |/ /_ / ___ \ 
// |_|\_\___|_| \_/____/_/   \_\

/// @notice XKZA - Kinza protocol Voter
/// @title Voter
/// @notice vote for underlying AToken/DToken holder
///         for receiving KZA emission on BaseRewardPool
contract Voter is Ownable {

    /*//////////////////////////////////////////////////////////////
                      CONSTANTS & IMMUTABLES
    //////////////////////////////////////////////////////////////*/
    uint internal constant DURATION = 7 days; // rewards are released over 7 days
    address public immutable xToken; // the xtoken that can vote on this contract
    address public immutable bribeAssetRegistry;

    /*//////////////////////////////////////////////////////////////
                    STORAGE VARIABLES & TYPES
    //////////////////////////////////////////////////////////////*/

    // simple re-entrancy check
    uint internal _unlocked = 1;

    IVoteLogic public voteLogic; // the voteLogic that can aggregate balance of XToken for this voter

    uint public totalWeight; // total voting weight

    address[] public markets; // all underlying viable for incentives

    uint256 public epoch;
    address public minter;
    mapping(address => address) public bribes; // underlying => external bribe (external bribes)

    mapping(address => uint256) public weights; // underlying => weight
    mapping(address => mapping(address => uint256)) public votes; // holder => underlying => votes
    mapping(address => address[]) public poolVote; // holder => underlying(s) that are voted
    mapping(address => uint) public usedWeights;  // address => total voting weight of user
    mapping(address => uint) public lastVoted; // holder => timestamp of last vote, to ensure one vote per epoch

    mapping(address => address) public delegation;

    /*//////////////////////////////////////////////////////////////
                              EVENTS
    //////////////////////////////////////////////////////////////*/

    event Voted(
        address indexed voter, 
        address pool, 
        uint256 weight, 
        uint256 epoch
    );

    event MarketBribeCreated(
        address market, 
        address bribe
    );

    event MarketBribeRemoved(
        address market
    );

    event NewVoteLogic(
        address newVoteLogic
    );

    event NewMinter(
        address newMinter
    );
    

    event Abstained(
        address voter, 
        uint256 weight, 
        uint256 epoch
    );

    event SetDelegation(
        address voter, 
        address delegatee
    );

    /*//////////////////////////////////////////////////////////////
                                MODIFIER
    //////////////////////////////////////////////////////////////*/
    modifier lock() {
        require(_unlocked == 1);
        _unlocked = 2;
        _;
        _unlocked = 1;
    }
    
    modifier onlyXToken() {
        require(msg.sender == xToken, "caller not xToken");
        _;
    }

    modifier onlyEpochSynced() {
        require(block.timestamp / DURATION == epoch, "epoch out of sync; please update epoch on Minter");
        _;
    }

    modifier onlyMinter() {
        require(msg.sender == minter, "caller not minter");
        _;
    }

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor(address _xToken, address _minter, address _voteLogic, address  _bribeAssetRegistry, address _governance) {
        xToken = _xToken;
        minter = _minter;
        voteLogic = IVoteLogic(_voteLogic);
        bribeAssetRegistry = _bribeAssetRegistry;
        epoch = block.timestamp / DURATION;
        transferOwnership(_governance);
        emit NewVoteLogic(_voteLogic);
    }


    /*//////////////////////////////////////////////////////////////
                            GETTERS
    //////////////////////////////////////////////////////////////*/
    function isDelegatedOrOwner(address _delegatee, address _voter) public view returns(bool) {
        return delegation[_voter] == _delegatee || msg.sender == _voter;
    }

    /// @notice helper function to get number of votable market
    function marketLength() external view returns (uint) {
        return markets.length;
    }

    /*//////////////////////////////////////////////////////////////
                            OWNABLE
    //////////////////////////////////////////////////////////////*/
    
    /// @param _underlying underlying assets which can be voted
    /// @dev only the underlying(s) that exist in the pool contract would be calculated
    ///      check minter update_period logic
    function pushUnderlying(address _underlying) external onlyOwner {
        require(bribes[_underlying] == address(0), "exists");
        address bribe = _createBribe(address(this), bribeAssetRegistry);
        bribes[_underlying] = bribe;
        markets.push(_underlying);
        emit MarketBribeCreated(_underlying, bribe);
    }

    function updateVoteLogic(address _newVoteLogic) external onlyOwner {
        voteLogic = IVoteLogic(_newVoteLogic);
        emit NewVoteLogic(_newVoteLogic);
    }

    function updateMinter(address _newMinter) external onlyOwner {
        require(minter != address(0), "minter can not be null");
        minter = _newMinter;
        emit NewMinter(_newMinter);
    }

    // repeat the last vote (same ratio) but update user with his latest balance
    // this is only callable from XToken
    function reVote(address _xTokenHolder) onlyXToken onlyEpochSynced external {
        // if the user has never voted, no refreshing is needed
        if(lastVoted[_xTokenHolder] == 0) {
            return;
        }
        lastVoted[_xTokenHolder] = block.timestamp;

        address[] memory _poolVote = poolVote[_xTokenHolder];
        uint _poolCnt = _poolVote.length;
        uint256[] memory _weights = new uint256[](_poolCnt);

        for (uint i = 0; i < _poolCnt; i ++) {
            _weights[i] = votes[_xTokenHolder][_poolVote[i]];
        }
        _vote(_xTokenHolder, _poolVote, _weights);
    }

    /*//////////////////////////////////////////////////////////////
                         USER INTERACTION
    //////////////////////////////////////////////////////////////*/
    function sync(uint256 _epoch) onlyMinter external {
        epoch = _epoch;
    }
    /// @notice user can update their vote, only the last vote before an epoch is counted
    /// @param _account the owner of the bribe, essentially this contract
    /// @param _poolVote the list of pool addresses
    /// @param _weights the list of relative weights for each pool
    function vote(address _account, address[] calldata _poolVote, uint256[] calldata _weights) external onlyEpochSynced {
        require(isDelegatedOrOwner(msg.sender, _account), "not owner or delegated");
        require(_poolVote.length == _weights.length, "number of pools and weights do not match");
        lastVoted[_account] = block.timestamp;
        // _vote would erase all records and re-cast vote, quite gas expensive
        _vote(_account, _poolVote, _weights);
    }

    /// @param _delegatee the address that user would like to delegate
    function updateDelegate(address _delegatee) external {
        delegation[msg.sender] = _delegatee;
        emit SetDelegation(msg.sender, _delegatee);
    }
    
    /// @notice in external bribe u can choose which token to claim
    /// @param _bribes each address of the bribe deployment
    /// @param _tokens for each bribe, the token(s) to claim
    /// @param _to the recipient
    function claimBribes(address[] memory _bribes, address[][] memory _tokens, address _to) external {
        require(_bribes.length > 0 && _tokens.length == _bribes.length, "bribe input validation fails");
        address bribe;
        for (uint i = 0; i < _bribes.length; i++) {
            bribe = _bribes[i];
            require(bribe != address(0), "bribe addresses cannot be zero");
            IBribe(bribe).getRewardForOwner(_tokens[i], msg.sender, _to);
        }
    }

    /*//////////////////////////////////////////////////////////////
                         INTERNAL FUNCTION
    //////////////////////////////////////////////////////////////*/

    /// @param _owner the owner of the bribe, essentially this contract
    /// @param _registry the whitelist asset registry
    /// @return bribe the address of the newly deployed bribe contract
    function _createBribe(address _owner, address _registry) internal returns(address bribe) {
        bribe = address(new AggregateBribe(_owner, _registry));
    }

    /// @param _account the owner of the bribe, essentially this contract
    /// @param _poolVote the list of pool addresses
    /// @param _weights the list of relative weights for each pool
    /// @dev make sure neither 
    ///      1.) the sum of _weights 
    ///      2.) each _weight * balanceOf 
    ///      does not exceeds 2**256 -1
    ///      or the function would revert due to overflow
    function _vote(address _account, address[] memory _poolVote, uint256[] memory _weights) internal {
        _reset(_account);
        uint256 _weight = IVoteLogic(voteLogic).balanceOf(_account);
        if (_weight == 0) {
            return;
        }
        uint _poolCnt = _poolVote.length;
        uint256 _totalVoteWeight;
        uint256 _poolWeight;
        address _pool;

        for (uint i; i < _poolCnt;) {
            _totalVoteWeight += _weights[i];
            // save gas
            unchecked {
                ++i;
            }
        }
        for (uint i; i < _poolCnt;) {
            _pool = _poolVote[i];
            // _poolWeight is the actual weight, xToken 1 : 1
            _poolWeight = _weights[i] * _weight / _totalVoteWeight;
            // sanity check, it's always true given the _reset executes prior
            require(votes[_account][_pool] == 0, "non-zero existing vote");
            // a _weight of 0 should NOT be passed to this function
            require(_poolWeight != 0, "zero pool weight");
            poolVote[_account].push(_pool);

            weights[_pool] += _poolWeight;
            votes[_account][_pool] += _poolWeight;
            IBribe(bribes[_pool])._deposit(uint256(_poolWeight), _account);
            emit Voted(_account, _pool, _poolWeight, block.timestamp / DURATION);
            // save gas
            unchecked {
                ++i;
            }
        }
        usedWeights[_account] = _weight;
        totalWeight += _weight;
    }

    /// @notice remove the last vote of the user
    /// @param _account the account to reset votes
    function _reset(address _account) internal {
        address[] storage _poolVote = poolVote[_account];
        uint _poolVoteCnt = _poolVote.length;
        uint256 last_weight = usedWeights[_account];
        // each underlying that gets voted in the last voted epoch
        for (uint i = 0; i < _poolVoteCnt; i ++) {
            address _pool = _poolVote[i];
            uint256 _votes = votes[_account][_pool];

            if (_votes != 0) {
                weights[_pool] -= _votes;
                votes[_account][_pool] -= _votes;
                IBribe(bribes[_pool])._withdraw(uint256(_votes), _account);
                emit Abstained(_account, _votes, block.timestamp / DURATION);
            }
        }
        totalWeight -= last_weight;
        usedWeights[_account] = 0;
        delete poolVote[_account];
    }
}