
// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.17;
import "forge-std/Script.sol";
import "../src/contracts/VoteDataProvider.sol";
import "../src/interfaces/IEmissionManager.sol";

contract DeployVoteDataProvider is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address xkza = vm.envAddress("XKZA");

        vm.startBroadcast(deployerPrivateKey);

        new VoteDataProvider(xkza);

        vm.stopBroadcast();
    }
}