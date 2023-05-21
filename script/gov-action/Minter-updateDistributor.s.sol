// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.17;

import "forge-std/Script.sol";
import "../../src/contracts/KZA/Minter.sol";

contract MinterUpdateVoter is Script {
    function run() external {
        uint256 govPrivateKey = vm.envUint("PRIVATE_KEY_GOV");
        address minter = vm.envAddress("Minter");
        address dist = vm.envAddress("KZADistributor");
        vm.startBroadcast(govPrivateKey);

        Minter(minter).updateDistributor(dist);

        vm.stopBroadcast();
    }
}
