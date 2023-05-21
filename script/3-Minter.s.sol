// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.17;

import "forge-std/Script.sol";
import "../src/contracts/KZA/Minter.sol";

contract DeployMinter is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address GOV = vm.envAddress("GOV");
        address kza = vm.envAddress("KZA");
        address pool = vm.envAddress("Pool");
        vm.startBroadcast(deployerPrivateKey);

        new Minter(pool, kza, GOV);

        vm.stopBroadcast();
    }
}
