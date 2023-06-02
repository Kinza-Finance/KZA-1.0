// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import '@openzeppelin/utils/math/Math.sol';
import '@openzeppelin/token/ERC20/IERC20.sol';
import '../../interfaces/IBribeAssetRegistry.sol';


// | |/ /_ _| \ | |__  /  / \   
// | ' / | ||  \| | / /  / _ \  
// | . \ | || |\  |/ /_ / ___ \ 
// |_|\_\___|_| \_/____/_/   \_\

/// @notice KZA - Kinza protocol bribe contract for each underlying asset
/// @title AggregateBribe
/// @notice Bribe pay out rewards for a given pool based on the votes 
///         that were received from the user through the contract Voter
contract AggregateBribe {
    /*//////////////////////////////////////////////////////////////
                        CONSTANTS & IMMUTABLES
    //////////////////////////////////////////////////////////////*/
    address public immutable voter; // only voter can modify balances (since it only happens on vote())
    address public immutable bribeAssetRegistry;

    uint internal constant DURATION = 7 days; // rewards are released over the voting period

    /*//////////////////////////////////////////////////////////////
                        STORAGE VARIABLES & TYPES
    //////////////////////////////////////////////////////////////*/
    uint internal _unlocked = 1;
    uint public totalSupply;
    // user => balanceOf (virtual), updated during vote
    mapping(address => uint) public balanceOf;
    mapping(address => mapping(uint => uint)) public tokenRewardsPerEpoch;
    // token => timestamp
    mapping(address => uint) public periodFinish;
    // token => user => amount
    mapping(address => mapping(address => uint)) public lastEarn;

    /// @notice A record of balance checkpoints for each account, by index
    mapping (address => mapping (uint => Checkpoint)) public checkpoints;
    /// @notice The number of checkpoints for each account at each change(s)
    mapping (address => uint) public numCheckpoints;
    /// @notice A record of total supply checkpoints, by index
    mapping (uint => SupplyCheckpoint) public supplyCheckpoints;
    /// @notice The number of checkpoints
    uint public supplyNumCheckpoints;

    /// @notice A checkpoint for marking balance
    struct Checkpoint {
        uint timestamp;
        uint balanceOf;
    }

    /// @notice A checkpoint for marking supply
    struct SupplyCheckpoint {
        uint timestamp;
        uint supply;
    }

    /*//////////////////////////////////////////////////////////////
                              EVENTS
    //////////////////////////////////////////////////////////////*/

    event Deposit(
        address indexed from, 
        address account, 
        uint amount
    );

    event Withdraw(
        address indexed from, 
        address account, 
        uint amount
    );

    event NotifyReward(
        address indexed from, 
        address indexed reward, 
        uint epoch, 
        uint amount
    );

    event ClaimRewards(
        address indexed from, 
        address indexed reward, 
        uint amount
    );

    /*//////////////////////////////////////////////////////////////
                          MODIFIER
    //////////////////////////////////////////////////////////////*/
    /// @notice simple re-entrancy check
    modifier lock() {
        require(_unlocked == 1);
        _unlocked = 2;
        _;
        _unlocked = 1;
    }

    /*//////////////////////////////////////////////////////////////
                          CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor(address _voter, address _bribeAssetRegistry) {
        voter = _voter;
        bribeAssetRegistry = _bribeAssetRegistry;
    }

    /*//////////////////////////////////////////////////////////////
                            GETTER / VIEW
    //////////////////////////////////////////////////////////////*/

    /// @param timestamp timestamp in second
    /// @return return the start of an epoch for that timestamp
    function getEpochStart(uint timestamp) public pure returns (uint) {
        uint bribeStart = _bribeStart(timestamp);
        uint bribeEnd = bribeStart + DURATION;
        return timestamp < bribeEnd ? bribeStart : bribeStart + DURATION;
    }

    /// @notice Determine the prior balance for an account as of a block number
    /// @dev Block number must be a finalized block or else this function will revert to prevent misinformation.
    /// @param account The address of user
    /// @param timestamp The timestamp to get the balance at
    /// @return The balance index the account had as of the given timestamp
    function getPriorBalanceIndex(address account, uint timestamp) public view returns (uint) {
        uint nCheckpoints = numCheckpoints[account];
        if (nCheckpoints == 0) {
            return 0;
        }
        // First check most recent balance
        if (checkpoints[account][nCheckpoints - 1].timestamp <= timestamp) {
            return (nCheckpoints - 1);
        }
        // Next check implicit zero balance
        if (checkpoints[account][0].timestamp > timestamp) {
            return 0;
        }

        uint lower = 0;
        uint upper = nCheckpoints - 1;
        while (upper > lower) {
            uint center = upper - (upper - lower) / 2; // ceil, avoiding overflow
            Checkpoint memory cp = checkpoints[account][center];
            if (cp.timestamp == timestamp) {
                return center;
            } else if (cp.timestamp < timestamp) {
                lower = center;
            } else {
                upper = center - 1;
            }
        }
        return lower;
    }

    /// @notice Determine the prior total supply as of a timestamp
    /// @param timestamp timestamp in second
    function getPriorSupplyIndex(uint timestamp) public view returns (uint) {
        uint nCheckpoints = supplyNumCheckpoints;
        if (nCheckpoints == 0) {
            return 0;
        }

        // First check most recent balance
        if (supplyCheckpoints[nCheckpoints - 1].timestamp <= timestamp) {
            return (nCheckpoints - 1);
        }

        // Next check implicit zero balance
        if (supplyCheckpoints[0].timestamp > timestamp) {
            return 0;
        }

        uint lower = 0;
        uint upper = nCheckpoints - 1;
        while (upper > lower) {
            uint center = upper - (upper - lower) / 2; // ceil, avoiding overflow
            SupplyCheckpoint memory cp = supplyCheckpoints[center];
            if (cp.timestamp == timestamp) {
                return center;
            } else if (cp.timestamp < timestamp) {
                lower = center;
            } else {
                upper = center - 1;
            }
        }
        return lower;
    }

    /// @param token the reward token
    /// @return the last time the reward was modified or periodFinish if the reward has ended
    function lastTimeRewardApplicable(address token) public view returns (uint) {
        return Math.min(block.timestamp, periodFinish[token]);
    }

    /// @notice function to return the earned/claimable reward for a user
    /// @param token reward token
    /// @param account target user
    /// @return the claimable
    function earned(address token, address account) public view returns (uint) {
        uint _startTimestamp = lastEarn[token][account];
        if (numCheckpoints[account] == 0) {
            return 0;
        }

        uint _startIndex = getPriorBalanceIndex(account, _startTimestamp);
        uint _endIndex = numCheckpoints[account]-1;

        uint reward = 0;
        // you only earn once per epoch (after it's over)
        Checkpoint memory prevRewards; // reuse struct to avoid stack too deep
        prevRewards.timestamp = _bribeStart(_startTimestamp);
        uint _prevSupply = 1;

        if (_endIndex > 0) {
            for (uint i = _startIndex; i <= _endIndex - 1; i++) {
                Checkpoint memory cp0 = checkpoints[account][i];
                uint _nextEpochStart = _bribeStart(cp0.timestamp);
                // check that you've earned it
                // this won't happen until a week has passed
                if (_nextEpochStart > prevRewards.timestamp) {
                  reward += prevRewards.balanceOf;
                }

                prevRewards.timestamp = _nextEpochStart;
                _prevSupply = supplyCheckpoints[getPriorSupplyIndex(_nextEpochStart + DURATION)].supply;
                prevRewards.balanceOf = cp0.balanceOf * tokenRewardsPerEpoch[token][_nextEpochStart] / _prevSupply;
            }
        }

        Checkpoint memory cp = checkpoints[account][_endIndex];
        uint _lastEpochStart = _bribeStart(cp.timestamp);
        uint _lastEpochEnd = _lastEpochStart + DURATION;

        if (block.timestamp > _lastEpochEnd) {
          reward += cp.balanceOf * tokenRewardsPerEpoch[token][_lastEpochStart] / supplyCheckpoints[getPriorSupplyIndex(_lastEpochEnd)].supply;
        }

        return reward;
    }

    /// @notice get latest total reward for a token
    /// @param token the token address to view
    function left(address token) external view returns (uint) {
        uint adjustedTstamp = getEpochStart(block.timestamp);
        return tokenRewardsPerEpoch[token][adjustedTstamp];
    }

    /*//////////////////////////////////////////////////////////////
                            USER INTERACTION
    //////////////////////////////////////////////////////////////*/

    /// @notice allows a user to claim rewards for a given token
    /// @param tokens the reward token to claim
    function getReward(address[] memory tokens) external lock  {
        for (uint i = 0; i < tokens.length; i++) {
            uint _reward = earned(tokens[i], msg.sender);
            lastEarn[tokens[i]][msg.sender] = block.timestamp;
            if (_reward > 0) _safeTransfer(tokens[i], msg.sender, _reward);

            emit ClaimRewards(msg.sender, tokens[i], _reward);
        }
    }
    /// @notice allow batched reward claims
    /// @param tokens the reward token to claim
    /// @param account the account that collects the reward
    /// @param to the receiver of the reward
    function getRewardForOwner(address[] memory tokens, address account, address to) external lock  {
        require(msg.sender == voter || msg.sender == account, "only voter or self claim");
        for (uint i = 0; i < tokens.length; i++) {
            uint _reward = earned(tokens[i], account);
            lastEarn[tokens[i]][account] = block.timestamp;
            if (_reward > 0) _safeTransfer(tokens[i], to, _reward);

            emit ClaimRewards(account, tokens[i], _reward);
        }
    }


    /// @notice This is an external function, but internal notation is used 
    ///         since it can only be called "internally" from Voter
    /// @param amount amount of vote to be accounted
    /// @param account voter address
    function _deposit(uint amount, address account) external {
        require(msg.sender == voter, "not voter");

        totalSupply += amount;
        balanceOf[account] += amount;

        _writeCheckpoint(account, balanceOf[account]);
        _writeSupplyCheckpoint();

        emit Deposit(msg.sender, account, amount);
    }

    /// @notice This is an external function, but internal notation is used 
    ///         since it can only be called "internally" from Voter
    /// @param amount amount of vote to be accounted
    /// @param account voter address
    function _withdraw(uint amount, address account) external {
        require(msg.sender == voter, "not voter");

        totalSupply -= amount;
        balanceOf[account] -= amount;

        _writeCheckpoint(account, balanceOf[account]);
        _writeSupplyCheckpoint();

        emit Withdraw(msg.sender, account, amount);
    }

    /// @notice entry point to send in bribe token, prior whitelist on registry is needed
    ///         bribe sender also has to approve the quantity to enable transferFrom
    /// @param token token to send in
    /// @param amount amount to send in
    function notifyRewardAmount(address token, uint amount) external lock {
        require(amount > 0, "non zero bribe is needed");
        require(IBribeAssetRegistry(bribeAssetRegistry).isWhitelisted(token), "bribe token must be whitelisted");
        // bribes kick in at the start of next bribe period
        uint adjustedTstamp = getEpochStart(block.timestamp);
        uint epochRewards = tokenRewardsPerEpoch[token][adjustedTstamp];

        _safeTransferFrom(token, msg.sender, address(this), amount);
        tokenRewardsPerEpoch[token][adjustedTstamp] = epochRewards + amount;

        periodFinish[token] = adjustedTstamp + DURATION;

        emit NotifyReward(msg.sender, token, adjustedTstamp, amount);
    }

    /*//////////////////////////////////////////////////////////////
                          INTERNAL FUNCTION
    //////////////////////////////////////////////////////////////*/

    /// @notice general transferFrom of tokens
    /// @param token token to transfer 
    /// @param from sender
    /// @param to receiver
    /// @param value amount of token
    function _safeTransferFrom(address token, address from, address to, uint256 value) internal {
        require(token.code.length > 0);
        (bool success, bytes memory data) =
        token.call(abi.encodeWithSelector(IERC20.transferFrom.selector, from, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))));
    }

    /// @notice general transfer of tokens from this contract
    /// @param token token to transfer 
    /// @param to receiver
    /// @param value amount of token
    function _safeTransfer(address token, address to, uint256 value) internal {
        require(token.code.length > 0);
        (bool success, bytes memory data) =
        token.call(abi.encodeWithSelector(IERC20.transfer.selector, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))));
    }

    /// @notice writing checkpoint of account and their vote balance
    /// @param account voter address
    /// @param balance vote balance
    function _writeCheckpoint(address account, uint balance) internal {
        uint _timestamp = block.timestamp;
        uint _nCheckPoints = numCheckpoints[account];
        if (_nCheckPoints > 0 && checkpoints[account][_nCheckPoints - 1].timestamp == _timestamp) {
            checkpoints[account][_nCheckPoints - 1].balanceOf = balance;
        } else {
            checkpoints[account][_nCheckPoints] = Checkpoint(_timestamp, balance);
            numCheckpoints[account] = _nCheckPoints + 1;
        }
    }

    /// @notice writing checkpoint of total supply, which is vote balance
    function _writeSupplyCheckpoint() internal {
        uint _nCheckPoints = supplyNumCheckpoints;
        uint _timestamp = block.timestamp;

        if (_nCheckPoints > 0 && supplyCheckpoints[_nCheckPoints - 1].timestamp == _timestamp) {
            supplyCheckpoints[_nCheckPoints - 1].supply = totalSupply;
        } else {
            supplyCheckpoints[_nCheckPoints] = SupplyCheckpoint(_timestamp, totalSupply);
            supplyNumCheckpoints = _nCheckPoints + 1;
        }
    }

    /// @param timestamp timestamp in second
    /// @return the start time of the epoch corresponds to that timestamp
    function _bribeStart(uint timestamp) internal pure returns (uint) {
        return timestamp - (timestamp % (DURATION));
    }
}