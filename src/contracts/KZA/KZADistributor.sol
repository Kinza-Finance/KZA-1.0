// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {SafeERC20} from '@openzeppelin/token/ERC20/utils/SafeERC20.sol';
import {SafeCast} from '@openzeppelin/utils/math/SafeCast.sol';
import {IERC20} from '@openzeppelin/token/ERC20/IERC20.sol';
import {ERC20} from '@openzeppelin/token/ERC20/ERC20.sol';
import "@openzeppelin/access/Ownable.sol";
import "../../interfaces/IEMissionManager.sol";
import "../../interfaces/IPool.sol";
import "../../interfaces/IVault.sol";
import "../../libraries/DataTypes.sol";

import '../../libraries/UtilLib.sol';


// | |/ /_ _| \ | |__  /  / \   
// | ' / | ||  \| | / /  / _ \  
// | . \ | || |\  |/ /_ / ___ \ 
// |_|\_\___|_| \_/____/_/   \_\

/// @notice KZA - Kinza protocol KZA emission distributor
/// @title KZADistributor
/// @notice  disbributor controls the emission ratio of a/dToken, as
///          well as variableDebt/stableDebtToken. Emission is pulled
///          to the rewardsVault for escrow.
contract KZADistributor is Ownable {
    using SafeERC20 for IERC20;
    using SafeCast for uint256;
    /*//////////////////////////////////////////////////////////////
                        CONSTANTS & IMMUTABLES
    //////////////////////////////////////////////////////////////*/
    uint256 constant private REWARD_PERIOD = 7 days;
    uint256 constant private PRECISION = 10000;

    IERC20 public immutable REWARD;
    address public immutable minter;
    
    /*//////////////////////////////////////////////////////////////
                            STORAGE VARIABLES
    //////////////////////////////////////////////////////////////*/
    uint256 public ATokenRatio;
    uint256 public stableDebtTokenRatio;

    address public vault;
    IEmissionManager public emisisonManager;
    IPool public pool;

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/
    event NewVault(address oldVault, address newVault);
    event NewKTokenRatio(uint256 newKTokenRatio);
    event NewVariableDebtTokenRatio(uint256 newVariableDebtTokenRatio);

    constructor(address _governance, address _reward, address _minter, address _pool) {
        UtilLib.checkNonZeroAddress(_governance);
        UtilLib.checkNonZeroAddress(_reward);
        UtilLib.checkNonZeroAddress(_minter);
        UtilLib.checkNonZeroAddress(_pool);
        transferOwnership(_governance);
        REWARD = IERC20(_reward);
        minter = _minter;
        pool = IPool(_pool);
    }

    modifier onlyMinter() {
        require(minter == msg.sender, "onlyMinter");
        _;
    }

    /*//////////////////////////////////////////////////////////////
                            GETTER / VIEW
    //////////////////////////////////////////////////////////////*/
    
    /// @return return debtToken emission ratio vs aToken
    function DTokenRatio() internal view returns(uint256) {
        return PRECISION - ATokenRatio;
    }

    /// @return return varaibleDebttoken emission ratio vs variable
    function variableDebtTokenRatio() internal view returns(uint256) {
        return PRECISION - stableDebtTokenRatio;
    }

    /// @param asset address of an underlying asset
    /// @return the ReserveData for the asset
    function getReserveData(address asset) internal view returns(DataTypes.ReserveData memory) {
        return pool.getReserveData(asset);
    }

    /*//////////////////////////////////////////////////////////////
                            OWNABLE
    //////////////////////////////////////////////////////////////*/

    /// @notice vault holds escrow of the reward token
    /// @param _newVault address of the new vault
    function setVault(address _newVault) external onlyOwner {
        UtilLib.checkNonZeroAddress(_newVault);
        address oldVault = vault;
        vault = _newVault;
        emit NewVault(oldVault, _newVault);
    }

    /// @notice emissionManager is where a/dToken holder can claim reward
    /// @param _newEmissionManager address of the new emissionManager
    function setEmissionManager(address _newEmissionManager) external onlyOwner {
        UtilLib.checkNonZeroAddress(_newEmissionManager);
        address oldmanager = address(emisisonManager);
        emisisonManager = IEmissionManager(_newEmissionManager);
        emit NewVault(oldmanager, _newEmissionManager);
    }

    /// @param _newKTokenRatio new atoken emission ratio vs dtoken
    function updateKTokenRatio(uint256 _newKTokenRatio) external onlyOwner {
        require(_newKTokenRatio <= PRECISION);
        ATokenRatio = _newKTokenRatio;
        emit NewKTokenRatio(_newKTokenRatio);
    }

    /// @param _newStableDebtTokenRatio new stableDebtToken emission ratio vs variable
    function updateStableDebtTokenRatio(uint256 _newStableDebtTokenRatio) external onlyOwner {
        require(_newStableDebtTokenRatio <= PRECISION);
        stableDebtTokenRatio = _newStableDebtTokenRatio;
        emit NewVariableDebtTokenRatio(_newStableDebtTokenRatio);
    }

    /// @notice call by minter after minting new tokens to the vault
    /// @dev this func then set emission for aToken/dToken on emission manager
    /// @param _market underlying address to notifyReward
    /// @param _amount amount of KZA reward
    function notifyReward(address _market, uint256 _amount) external onlyMinter {
        // if vault is not set, this would block the notifyRewardCall
        require(vault != address(0), "vault needs to be set");
        require(address(emisisonManager) != address(0), "emisisonManager needs to be set");
        address _vault = vault;
        if (_amount != 0 ) {
            uint256 amountDToken = _amount * DTokenRatio() / PRECISION;
            uint256 amountAToken = _amount - amountDToken;

            uint256 DTokenVariable = amountDToken * variableDebtTokenRatio() / PRECISION;
            uint256 DTokenStable = amountDToken - DTokenVariable;
            
            REWARD.safeTransferFrom(minter, _vault, _amount);
            // so transferStrategy can pull this amount in total through increaseAllowance.
            IVault(_vault).approveTransferStrat(_amount);
            
            address token;
            uint256 rate;
            if (DTokenVariable != 0) {
                token = getReserveData(_market).variableDebtTokenAddress;
                rate = DTokenVariable / REWARD_PERIOD;
                _updateEmissionManager(token, address(REWARD), rate);
            }
            if (DTokenStable != 0) {
                token = getReserveData(_market).stableDebtTokenAddress;
                rate = DTokenStable / REWARD_PERIOD;
                _updateEmissionManager(token, address(REWARD), rate);
            }
            if (amountAToken != 0) {
                token = getReserveData(_market).aTokenAddress;
                rate = amountAToken / REWARD_PERIOD;
                _updateEmissionManager(token, address(REWARD), rate);
            }    
        }
    }
    function _updateEmissionManager(address _token, address _reward, uint256 _rate) internal {
        uint88[] memory rates = new uint88[](1);
        address[] memory rewards = new address[](1);
        rewards[0] = address(_reward);
        rates[0] = _rate.toUint88();
        emisisonManager.setDistributionEnd(_token, _reward,  uint32(block.timestamp + REWARD_PERIOD));
        emisisonManager.setEmissionPerSecond(_token, rewards, rates);
    }
    
}