// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {TransferStrategyBase} from './TransferStrategyBase.sol';
import {SafeERC20} from '@openzeppelin/token/ERC20/utils/SafeERC20.sol';
import {IERC20} from '@openzeppelin/token/ERC20/IERC20.sol';
import "../../interfaces/IKZA.sol";

// | |/ /_ _| \ | |__  /  / \   
// | ' / | ||  \| | / /  / _ \  
// | . \ | || |\  |/ /_ / ___ \ 
// |_|\_\___|_| \_/____/_/   \_\

/// @notice KZA - Kinza protocol transferStrategy
/// @title LockTransferStrategy
/// @notice define the lock/liquid ratio during the claim of KZA reward
///         on EmissionManager
///         the design of a rewardController is that each rewardToken can have a transferStrat
///         each transferStrategy can lead to its own vault.
contract LockTransferStrategy is TransferStrategyBase {
    using SafeERC20 for IERC20;

    /*//////////////////////////////////////////////////////////////
                        CONSTANTS & IMMUTABLES
    //////////////////////////////////////////////////////////////*/
    uint256 private constant PRECISION = 10000;
    address internal immutable REWARDS_VAULT;
    address internal immutable KZA;
    IKZA internal immutable XKZA;

    /*//////////////////////////////////////////////////////////////
                          STORAGE VARIABLE
    //////////////////////////////////////////////////////////////*/
    uint256 public lockRatio = 8500;

    event NewLockRatio(uint256 newLockRatio);

    constructor(
      address incentivesController,
      address gov,
      address rewardsVault,
      address xkza
    ) TransferStrategyBase(incentivesController, gov) {
      REWARDS_VAULT = rewardsVault;
      XKZA = IKZA(xkza);
      KZA = XKZA.KZA();
      // approve xkza for locking
      IERC20(KZA).approve(xkza, type(uint256).max);
      // the allowance of the transferStrategy would be revoked on the vault side if it gets sunset.
      // so entry to revoke it's own allowance on xkza is unnecessary
    }


    /*//////////////////////////////////////////////////////////////
                              OWNABLE
    //////////////////////////////////////////////////////////////*/
    function updateLockRatio(uint256 newLockRatio) external onlyOwner {
      require(newLockRatio <= PRECISION, "new lock ratio above 100%");
      lockRatio = newLockRatio;
      emit NewLockRatio(newLockRatio);
    }

    /// @notice callable from the emission manager, pull fund from rewardsVault
    /// @param to the receiver of reward
    /// @param reward the reward token
    /// @param amount the amount to claim
    function performTransfer(address to, address reward, uint256 amount)
      external
      override
      onlyIncentivesController
      returns (bool)
    {
      if (reward == KZA) {
        uint256 lock = amount * lockRatio / PRECISION;
        uint256 liquid = amount - lock;
        // pull the lock part to this address first
        IERC20(reward).safeTransferFrom(REWARDS_VAULT, address(this), lock);
        // lock directly for the user
        XKZA.convertTo(lock, to);
        IERC20(reward).safeTransferFrom(REWARDS_VAULT, to, liquid);
        return true;
      }
    }
}