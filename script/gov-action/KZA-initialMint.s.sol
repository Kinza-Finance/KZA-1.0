// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.17;

import "forge-std/Script.sol";
import "../../src/contracts/KZA/KZA.sol";

contract KZAInitialMint is Script {
    function run() external {
        uint256 govPrivateKey = vm.envUint("PRIVATE_KEY_GOV");
        address kza = vm.envAddress("KZA");
        address initialMintTarget = vm.envAddress("Treasury");
        vm.startBroadcast(govPrivateKey);

        KZA(kza).initialMint(initialMintTarget);

        vm.stopBroadcast();
    }
}
