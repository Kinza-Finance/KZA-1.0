// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/access/Ownable.sol";

import '../../libraries/UtilLib.sol';
// | |/ /_ _| \ | |__  /  / \   
// | ' / | ||  \| | / /  / _ \  
// | . \ | || |\  |/ /_ / ___ \ 
// |_|\_\___|_| \_/____/_/   \_\

/// @notice KZA - Kinza protocol bribe asset registry
/// @title BribeAssetRegistry
/// @notice admin control this registry for which bribe asset
///         can be sent in to the AggregateBribe through notifyRewardAmount
contract BribeAssetRegistry is Ownable {
    // tokenAddress(USDC,USDT) => bribeToken => true/false
    mapping(address => mapping(address => bool)) private whitelist;

    event AddWhitelistAsset(address indexed underlying, address indexed asset);
    event RemoveWhitelistAsset(address indexed underlying, address indexed asset);

    constructor(address _governance) {
        UtilLib.checkNonZeroAddress(_governance);
        transferOwnership(_governance);
    }

    /// @param _asset asset to be added into the whitelist
    function addAsset(address _underlying, address _asset) external onlyOwner {
        require(!whitelist[_underlying][_asset], "asset whitelisted");
        whitelist[_underlying][_asset] = true;
        emit AddWhitelistAsset(_underlying, _asset);
    }

    /// @param _asset asset to be removed from the whitelist
    function removeAsset(address _underlying, address _asset) external onlyOwner {
        require(whitelist[_underlying][_asset], "asset not whitelisted");
        whitelist[_underlying][_asset] = false;
        emit RemoveWhitelistAsset(_underlying, _asset);
    }

    /// @param _asset asset to be checked
    function isWhitelisted(address _reserve, address _asset) external view returns (bool) {
        return whitelist[_reserve][_asset];
    }
}