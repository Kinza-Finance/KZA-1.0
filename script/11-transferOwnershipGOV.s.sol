
// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.17;
import "forge-std/Script.sol";
import "../src/contracts/integration/LockTransferStrategy.sol";
import "../src/contracts/KZA/KZA.sol";
import "../src/contracts/KZA/Minter.sol";
import "../src/contracts/KZA/XKZA.sol";
import "../src/contracts/integration/RewardsVault.sol";
import "../src/contracts/KZA/KZADistributor.sol";
//import "../src/contracts/lending/EmissionManager.sol";


contract TransferOwnership is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address GOV = vm.envAddress("GOV");
        address kza = vm.envAddress("KZA");
        address minter = vm.envAddress("Minter");
        address xkza = vm.envAddress("XKZA");
        address rv = vm.envAddress("RewardsVault");
        address kdist = vm.envAddress("KZADistributor");
        //address em = vm.envAddress("EmissionManager");
        address ts = vm.envAddress("LockTransferStrategy");
        
        vm.startBroadcast(deployerPrivateKey);

        KZA(kza).proposeNewGovernance(GOV);
        Minter(minter).transferOwnership(GOV);
        XKZA(xkza).transferOwnership(GOV);
        RewardsVault(rv).transferOwnership(GOV);
        KZADistributor(kdist).transferOwnership(GOV);
        //EmissionManager(em).transferOwnership(GOV);
        LockTransferStrategy(ts).transferOwnership(GOV);

        vm.stopBroadcast();
    }
}