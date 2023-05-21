// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.17;

import "forge-std/Script.sol";
import "../src/contracts/integration/ReserveFeeDistributor.sol";

contract DeployReserveFeeDistributor is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address GOV = vm.envAddress("GOV");
        address treasury = vm.envAddress("Treasury");
        address voter = vm.envAddress("Voter");
        address pool = vm.envAddress("Pool");
        vm.startBroadcast(deployerPrivateKey);

        new ReserveFeeDistributor(GOV, treasury, pool, voter);

        vm.stopBroadcast();
    }
}
