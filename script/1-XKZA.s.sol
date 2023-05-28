// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.17;

import "forge-std/Script.sol";
import "../src/contracts/KZA/XKZA.sol";

contract DeployXKZA is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address GOV = vm.envAddress("deployer");
        address kza = vm.envAddress("KZA");
        vm.startBroadcast(deployerPrivateKey);

        new XKZA(kza, GOV);

        vm.stopBroadcast();
    }
}