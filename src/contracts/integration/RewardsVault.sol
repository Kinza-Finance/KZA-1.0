// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/access/Ownable.sol";
import "../../interfaces/IKZA.sol";

// | |/ /_ _| \ | |__  /  / \   
// | ' / | ||  \| | / /  / _ \  
// | . \ | || |\  |/ /_ / ___ \ 
// |_|\_\___|_| \_/____/_/   \_\

/// @notice KZA - Kinza protocol rewardsVault
/// @title RewardsVault
/// @notice escrow of emission rewards
///         the expected workflow is distributor would increase an allowance
///         which would be claimed by transferStrategy subsequently
contract RewardsVault is Ownable {

    IKZA public immutable REWARD;
    address public immutable distributor;

    address public transferStrategy;
    
    event NewTransferStrat(address oldTransferStrategy, address newTransferStrategy);

    constructor(address _governance, address _distributor, address _reward) {
        transferOwnership(_governance);
        REWARD = IKZA(_reward);
        distributor = _distributor;
    }

    modifier onlyDisbributor() {
        require(distributor == msg.sender, "onlyDisbributor");
        _;
    }

    /*//////////////////////////////////////////////////////////////
                                OWNABLE
    //////////////////////////////////////////////////////////////*/
    
    /// @dev update the active transferStrategy after invalidating the previous one
    function updateTransferStrat(address _newTransferStrategy) external onlyOwner {
        address oldTransferStrategy = transferStrategy;
        if (oldTransferStrategy != address(0)) {
            REWARD.approve(oldTransferStrategy, 0);
        }
        transferStrategy = _newTransferStrategy;
        emit NewTransferStrat(oldTransferStrategy, _newTransferStrategy);
    
    }

    /// @dev call by emission distributor after minting new token to the vault
    function approveTransferStrat(uint256 _amount) external onlyDisbributor {
        REWARD.increaseAllowance(transferStrategy, _amount);
    }

    /// @dev rescue fund in case of sunset
    function resecureFund(uint256 _amount) external onlyOwner {
        REWARD.transfer(owner(), _amount);
    }

    /// @dev invalidate a transferStrategy
    function sunsetTransferStrat(address strategy) external onlyOwner {
        REWARD.approve(strategy, 0);
    }
}