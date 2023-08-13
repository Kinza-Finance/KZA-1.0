// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.17;
import "forge-std/Script.sol";
import "../src/contracts/integration/RewardsVault.sol";

contract DeployRewardsVault is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address GOV = vm.envAddress("GOV");
        address dist = vm.envAddress("KZADistributor");
        address kza = vm.envAddress("KZA");
        vm.startBroadcast(deployerPrivateKey);

        new RewardsVault(GOV, dist, kza);

        vm.stopBroadcast();
    }
}