// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.17;

import "forge-std/Script.sol";
import "../src/contracts/KZA/Voter.sol";

contract DeployVoter is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address GOV = vm.envAddress("GOV");
        address xkza = vm.envAddress("XKZA");
        address minter = vm.envAddress("Minter");
        address registry = vm.envAddress("BribeAssetRegistry");
        address votelogic = vm.envAddress("VoteLogic");
        vm.startBroadcast(deployerPrivateKey);

        new Voter(xkza, minter, votelogic, registry, GOV);

        vm.stopBroadcast();
    }
}
