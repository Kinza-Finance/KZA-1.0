// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.17;

import "forge-std/Script.sol";
import "../../src/contracts/KZA/BribeAssetRegistry.sol";
import "../../src/interfaces/IPoolDataProvider.sol";

// BribeToken is supposed to be aToken
contract RegistryPushBribeToken is Script {
    function run() external {
        uint256 govPrivateKey = vm.envUint("PRIVATE_KEY_GOV");
        address registry = vm.envAddress("BribeAssetRegistry");
        address dataProvider = vm.envAddress("PoolDataProvider");
        IPoolDataProvider.TokenData[] memory aTokens = IPoolDataProvider(dataProvider).getAllATokens();
    
        vm.startBroadcast(govPrivateKey);

        for (uint i; i < aTokens.length;++i) {
            address aToken = aTokens[i].tokenAddress;
            BribeAssetRegistry(registry).addAsset(aToken);
        }
        vm.stopBroadcast();
        
    }
}
