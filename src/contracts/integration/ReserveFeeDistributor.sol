// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {SafeERC20} from '@openzeppelin/token/ERC20/utils/SafeERC20.sol';
import {ERC20} from '@openzeppelin/token/ERC20/ERC20.sol';
import {DataTypes} from '../../libraries/DataTypes.sol';
import "@openzeppelin/access/Ownable.sol";

import "../../interfaces/IBribe.sol";
import "../../interfaces/IVoter.sol";
import "../../interfaces/IPool.sol";

// | |/ /_ _| \ | |__  /  / \   
// | ' / | ||  \| | / /  / _ \  
// | . \ | || |\  |/ /_ / ___ \ 
// |_|\_\___|_| \_/____/_/   \_\

/// @notice KZA - Kinza protocol ReserveFeeDistributor
/// @title ReserveFeeDistributor
/// @notice claim reserve from the core lending system as the treasury
///         send the reserve fee generated from each pool 
///         to the corresponding bribe(s) contract on each epoch
contract ReserveFeeDistributor is Ownable {
    using SafeERC20 for ERC20;

    /*//////////////////////////////////////////////////////////////
                        CONSTANTS & IMMUTABLES
    //////////////////////////////////////////////////////////////*/
    uint256 private constant PRECISION = 10000;
    uint256 public bribeRatio = 5000;

    IPool public immutable pool;
    IVoter public immutable voter;
    address public immutable treasury;
    
    event NewBribeRatio(uint256 newBribeRatio);
    

    constructor(address _governance, address _treasury, address _pool, address _voter) {
        transferOwnership(_governance);
        treasury = _treasury;
        pool = IPool(_pool);
        voter = IVoter(_voter);
    }

    /*//////////////////////////////////////////////////////////////
                                OWNABLE
    //////////////////////////////////////////////////////////////*/
    /// @param _newBribeRatio the new ratio of revenue sent as bribe
    function updateBribeRatio(uint256 _newBribeRatio) external onlyOwner {
        require(_newBribeRatio <= PRECISION);
        bribeRatio = _newBribeRatio;
        emit NewBribeRatio(_newBribeRatio);
    }

    /*//////////////////////////////////////////////////////////////
                                CALLABLE
    //////////////////////////////////////////////////////////////*/
    /// @notice this splits the treasury already sent to this address
    /// @param _assets underlying asset that has acurred treasury
    /// @dev revenue would be split in form of aToken
    function splits(address[] calldata _assets) external {
        uint256 length = _assets.length;
        for (uint256 i;i < length;) {
            _split(_assets[i]);
            unchecked {
                ++i;
            }
        }
    }

    /// @notice this pull the treasury(per pool) to the treasury, which is this address
    /// @param _assets underlying assets 
    /// @dev aToken would be pulled into this address
    function pullFromTreasury(address[] calldata _assets) external {
        IPool(pool).mintToTreasury(_assets);
    }

    /// @dev a bundled function
    /// @param _assets underlying assets 
    function pullFromTreasuryAndSplit(address[] calldata _assets) external {
        IPool(pool).mintToTreasury(_assets);
        uint256 length = _assets.length;
        for (uint256 i;i < length;) {
            _split(_assets[i]);
            unchecked {
                ++i;
            }
        }
    }
    /*//////////////////////////////////////////////////////////////
                                INTERNAL
    //////////////////////////////////////////////////////////////*/
    ///
    function _split(address _asset) internal {
        address _aToken = _getReserveData(_asset).aTokenAddress;
        IBribe bribe = IBribe(voter.bribes(_asset));
        uint256 currentBalance = ERC20(_aToken).balanceOf(address(this));
        if (currentBalance != 0) {
            uint256 toBribe = currentBalance * bribeRatio / PRECISION;
            uint256 toTreasury = currentBalance - toBribe;

            ERC20(_aToken).safeTransfer(treasury, toTreasury);
            // notifyReward would pull from this address
            ERC20(_aToken).increaseAllowance(address(bribe), toBribe);
            bribe.notifyRewardAmount(_aToken, toBribe);
        }
    }

    function _getReserveData(address asset) internal view returns(DataTypes.ReserveData memory) {
        return pool.getReserveData(asset);
    }

}