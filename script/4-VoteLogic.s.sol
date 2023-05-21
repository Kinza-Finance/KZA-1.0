// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.17;

import "forge-std/Script.sol";
import "../src/contracts/KZA/VoteLogic.sol";

contract DeployVoteLogic is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address GOV = vm.envAddress("GOV");
        address xkza = vm.envAddress("XKZA");
        vm.startBroadcast(deployerPrivateKey);

        new VoteLogic(xkza, GOV);

        vm.stopBroadcast();
    }
}
