// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.17;

import "forge-std/Script.sol";
import "../src/contracts/KZA/Minter.sol";
import "../src/interfaces/IPoolAddressesProvider.sol";
import "../src/contracts/KZA/KZA.sol";

contract DeployMinter is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address GOV = vm.envAddress("GOV");
        address kza = vm.envAddress("KZA");
        address provider = vm.envAddress("PoolAddressesProvider");

        address pool = IPoolAddressesProvider(provider).getPool();
        // console2.log("pool address: ", pool);

        vm.startBroadcast(deployerPrivateKey);

        new Minter(pool, kza, GOV);

        vm.stopBroadcast();
    }
}
