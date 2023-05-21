// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.17;

import "forge-std/Script.sol";
import "../../src/contracts/KZA/KZADistributor.sol";

contract EDistributorSetVault is Script {
    function run() external {
        uint256 govPrivateKey = vm.envUint("PRIVATE_KEY_GOV");
        address dist = vm.envAddress("KZADistributor");
        address rv = vm.envAddress("RewardsVault");
        vm.startBroadcast(govPrivateKey);

        KZADistributor(dist).setVault(rv);

        vm.stopBroadcast();
    }
}
