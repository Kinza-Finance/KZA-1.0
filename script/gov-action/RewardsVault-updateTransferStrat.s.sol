// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.17;

import "forge-std/Script.sol";
import "../../src/contracts/integration/RewardsVault.sol";

contract RewardsVaultUpdateLockTransferStrat is Script {
    function run() external {
        uint256 govPrivateKey = vm.envUint("PRIVATE_KEY_GOV");
        address rv = vm.envAddress("RewardsVault");
        address ts = vm.envAddress("LockTransferStrategy");
        vm.startBroadcast(govPrivateKey);

        RewardsVault(rv).updateTransferStrat(ts);

        vm.stopBroadcast();
    }
}
