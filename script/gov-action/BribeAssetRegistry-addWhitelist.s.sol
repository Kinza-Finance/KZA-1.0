// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.17;

import "forge-std/Script.sol";
import "../../src/contracts/KZA/BribeAssetRegistry.sol";

contract RegistryAddWhitelist is Script {
    function run() external {
        uint256 govPrivateKey = vm.envUint("PRIVATE_KEY_GOV");
        address reg = vm.envAddress("BribeAssetRegistry");
        string[] memory underlyings = new string[](6);
        underlyings[0] = "underlying_USDC";
        underlyings[1] = "underlying_WBTC";
        underlyings[2] = "underlying_WETH";
        underlyings[3] = "underlying_USDT";
        underlyings[4] = "underlying_BUSD";
        underlyings[5] = "underlying_USDC";
        uint256 length = underlyings.length;
        vm.startBroadcast(govPrivateKey);
        for (uint i; i < length;++i) {
            address underlying = vm.envAddress(underlyings[i]);
            BribeAssetRegistry(reg).addAsset(underlying);

        }
        vm.stopBroadcast();
        
    }
}
