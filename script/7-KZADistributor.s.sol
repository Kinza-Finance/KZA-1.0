// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.17;

import "forge-std/Script.sol";
import "../src/contracts/KZA/KZADistributor.sol";

contract DeployKZADistributor is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address GOV = vm.envAddress("deployer");
        address kza = vm.envAddress("KZA");
        address minter = vm.envAddress("Minter");
        address pool = vm.envAddress("Pool");
        vm.startBroadcast(deployerPrivateKey);

        new KZADistributor(GOV, kza, minter, pool);

        vm.stopBroadcast();
    }
}
