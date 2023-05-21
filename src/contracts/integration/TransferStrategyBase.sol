// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/access/Ownable.sol";
import {SafeERC20} from '@openzeppelin/token/ERC20/utils/SafeERC20.sol';
import {IERC20} from '@openzeppelin/token/ERC20/IERC20.sol';


// | |/ /_ _| \ | |__  /  / \   
// | ' / | ||  \| | / /  / _ \  
// | . \ | || |\  |/ /_ / ___ \ 
// |_|\_\___|_| \_/____/_/   \_\

/// @notice KZA - Kinza protocol transferStrategyBASE
/// @title TransferStrategyBase
/// @notice basic implementation of a transferStrategy
abstract contract TransferStrategyBase is Ownable {
  using SafeERC20 for IERC20;

  address internal immutable INCENTIVES_CONTROLLER;

  event EmergencyWithdrawal(
      address indexed caller,
      address indexed token,
      address indexed to,
      uint256 amount
    );

  constructor(address incentivesController, address gov) {
    INCENTIVES_CONTROLLER = incentivesController;
    transferOwnership(gov);
  }

  /// @dev Modifier for incentives controller only functions
  modifier onlyIncentivesController() {
    require(INCENTIVES_CONTROLLER == msg.sender, 'CALLER_NOT_INCENTIVES_CONTROLLER');
    _;
  }

  function getIncentivesController() external view returns (address) {
    return INCENTIVES_CONTROLLER;
  }

  function performTransfer(
    address to,
    address reward,
    uint256 amount
  ) external virtual returns (bool);

  function emergencyWithdrawal(
    address token,
    address to,
    uint256 amount
  ) external onlyOwner {
    IERC20(token).safeTransfer(to, amount);

    emit EmergencyWithdrawal(msg.sender, token, to, amount);
  }
}