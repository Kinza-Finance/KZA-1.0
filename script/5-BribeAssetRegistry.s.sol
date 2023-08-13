// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.17;

import "forge-std/Script.sol";
import "../src/contracts/KZA/BribeAssetRegistry.sol";

contract DeployBribeAssetRegistry is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address GOV = vm.envAddress("GOV");
        vm.startBroadcast(deployerPrivateKey);

        new BribeAssetRegistry(GOV);

        vm.stopBroadcast();
    }
}