// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.17;

import "forge-std/Script.sol";
import "../../src/contracts/KZA/XKZA.sol";

contract XKZAUpdateVoter is Script {
    function run() external {
        uint256 govPrivateKey = vm.envUint("PRIVATE_KEY_GOV");
        address xkza = vm.envAddress("XKZA");
        address voter = vm.envAddress("Voter");
        vm.startBroadcast(govPrivateKey);

        XKZA(xkza).updateVoter(voter);

        vm.stopBroadcast();
    }
}
