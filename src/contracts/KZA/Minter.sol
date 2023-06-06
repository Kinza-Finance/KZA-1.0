// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "@openzeppelin/access/Ownable.sol";

import "../../interfaces/IVoter.sol";
import "../../interfaces/IDistributor.sol";
import "../../interfaces/IKZA.sol";
import "../../interfaces/IPool.sol";

import '../../libraries/UtilLib.sol';
// | |/ /_ _| \ | |__  /  / \   
// | ' / | ||  \| | / /  / _ \  
// | . \ | || |\  |/ /_ / ___ \ 
// |_|\_\___|_| \_/____/_/   \_\


/// @notice XKZA - Kinza protocol Minter
/// @title XKZA
/// @notice Minter mints tokens into emission according to schedule
///         initial epoch has a weekly emission of 463_345
///         each epoch has a reduction rate of 0.5%
///         the final epoch 208 would have a rate of ~164,165
///         the emission is distributed to DToken holder through KZADistributor.
///         the emission ratio across each pool is decided by the voter
contract Minter is Ownable {

    /*//////////////////////////////////////////////////////////////
                        CONSTANTS & IMMUTABLES
    //////////////////////////////////////////////////////////////*/

    uint internal constant WEEK = 7 days; // allows minting once per week (reset every Thursday 00:00 UTC)
    uint internal constant PRECISION = 10000;
    IKZA public immutable KZA;
    IPool public immutable pool;
    /*//////////////////////////////////////////////////////////////
                         STORAGE VARIABLES & TYPES
    //////////////////////////////////////////////////////////////*/

    // the only dependency to distribute reward tokens is referencing voter
    IVoter public voter;

    uint public decay = 100; // 0.5% weekly decay
    uint public emission = 684_642 * 1e18;
    uint public epoch;

    address public distributor;
    
    mapping(address => uint256) public rewardsCache;

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/
    event NewVoter(address _newVoter);
    event NewDecay(uint256 _newDecay);
    event NewDistributor(address _newDistributor);

    /*//////////////////////////////////////////////////////////////
                          CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor(
        address _pool,
        address _KZA,
        address _governance
    ) {
        UtilLib.checkNonZeroAddress(_pool);
        UtilLib.checkNonZeroAddress(_KZA);
        UtilLib.checkNonZeroAddress(_governance);
        pool = IPool(_pool);
        KZA = IKZA(_KZA);
        epoch = block.timestamp / WEEK;
        transferOwnership(_governance);
    }

    /// @notice gov can update voter 
    /// @param _newVoter the voter address that determines the allocation 
    ///        of each mint
    function updateVoter(address _newVoter) external onlyOwner {
        UtilLib.checkNonZeroAddress(_newVoter);
        voter = IVoter(_newVoter);
        emit NewVoter(_newVoter);
    }

    /// @notice gov can update voter 
    /// @param _newDecay the emission decay of each epoch (in bps)
    function updateDecay(uint256 _newDecay) external onlyOwner {
        require(_newDecay <= PRECISION, "decay exceeds maximum");
        decay = _newDecay;
        emit NewDecay(_newDecay);
    }

    /// @notice gov can update distributor 
    /// @param _newDistributor distributor can pull the emission out
    function updateDistributor(address _newDistributor) external onlyOwner {
        UtilLib.checkNonZeroAddress(_newDistributor);
        distributor = _newDistributor;
        emit NewDistributor(_newDistributor);
    }

    /// @notice update period can only be called once per cycle (1 week)
    /// @dev on each update, the reward (total emission) would be awarded
    ///      vote for all the active reserve pools would be checked
    ///      corresponding KZA reward would be added on rewardsCache
    function update_period() external returns (uint lastEpoch) {
        lastEpoch = epoch;
        uint current = block.timestamp / WEEK;
        require(address(voter) != address(0), "voter needs to be set");
        require(current > lastEpoch, "only trigger each new week"); 
        epoch = current;
        uint256 _emission = emission;
        uint256 prevEmission = _emission;
        KZA.mint(address(this), _emission);
        emission = (_emission * (PRECISION - decay)) / PRECISION;
        // get the scheduled total
        address[] memory reserves = getReserves();
        uint256 length = reserves.length;
        if (length != 0) {
            address market;
            uint256 reward;
            uint256 totalWeight = voter.totalWeight();
            if (totalWeight != 0) {
                for (uint i; i < length;) {
                market = reserves[i];
                uint256 vote = voter.weights(market);
                reward = prevEmission * vote / totalWeight;
                rewardsCache[market] += reward;
                unchecked {
                    ++i;
                    }  
                }
            }
        }
        voter.sync(epoch);
    }

    /// @notice notify the distributor on the reward amount for all pools
    /// @dev expect the distributor to pull the notified amount
    ///      through the function notifyReward
    function notifyRewards() external {
        address[] memory reserves = getReserves();
        uint256 length = reserves.length;
        require(length != 0, "no active pool");
        address market;
        uint256 amount;
        for (uint i; i < length;) {
            market = reserves[i];
            amount = rewardsCache[market];
            if (amount != 0) {
                rewardsCache[market] = 0;
                KZA.increaseAllowance(distributor, amount);
                // notifyReward would call safeTransferFrom
                IDistributor(distributor).notifyReward(market, amount);
            }
            unchecked {
                 ++i;
            }
        }
    }

    /// @notice notify the distributor on the reward amount for a single pool
    /// @dev expect the distributor to pull the notified amount
    ///      through the function notifyReward
    /// @param _market the market to send reward
    function notifyReward(address _market) external {
        require(distributor != address(0), "distributor is not set");
        uint256 amount = rewardsCache[_market];
        if(amount != 0) {
            rewardsCache[_market] = 0;
            KZA.increaseAllowance(distributor, amount);
            // notifyReward would call safetTransferFrom
            IDistributor(distributor).notifyReward(_market, amount);
        }
    }

    /// @notice helper function to retrieve the list of active pools
    function getReserves() public view returns(address[] memory) {
        return IPool(pool).getReservesList();

    }
}