
// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.17;
import "forge-std/Script.sol";
import "../src/contracts/integration/LockTransferStrategy.sol";
import "../src/interfaces/IEmissionManager.sol";

contract DeployRewardsVault is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address GOV = vm.envAddress("GOV");
        // address rc = vm.envAddress("RewardsController");
        address em = vm.envAddress("EmissionManager");
        address rv = vm.envAddress("RewardsVault");
        address xkza = vm.envAddress("XKZA");

        IRewardsController rewardController = IEmissionManager(em).getRewardsController();

        vm.startBroadcast(deployerPrivateKey);

        new LockTransferStrategy(address(rewardController), GOV, rv, xkza);

        vm.stopBroadcast();
    }
}