
// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "forge-std/Script.sol";
import "../../src/contracts/lending/EmissionManager.sol";

// this uses the mock emission manager, but shd point to the EmissionManager implemented from aave
contract EManagerSetEmissionAdmin is Script {
    function run() external {
        uint256 govPrivateKey = vm.envUint("PRIVATE_KEY_GOV");
        address em = vm.envAddress("EmissionManager");
        address kza = vm.envAddress("KZA");
        address emissionAdmin = vm.envAddress("GOV");
        vm.startBroadcast(govPrivateKey);

        EmissionManager(em).setEmissionAdmin(kza, emissionAdmin);

        vm.stopBroadcast();
    }
}
