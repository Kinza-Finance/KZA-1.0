// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.17;

import "forge-std/Script.sol";
import "../../src/contracts/KZA/Voter.sol";

contract VoterPushUnderlying is Script {
    function run() external {
        uint256 govPrivateKey = vm.envUint("PRIVATE_KEY_GOV");
        address voter = vm.envAddress("Voter");
        string[] memory underlyings = new string[](6);
        underlyings[0] = "UNDERLYING_BUSD";
        underlyings[1] = "UNDERLYING_USDC";
        underlyings[2] = "UNDERLYING_USDT";
        underlyings[3] = "UNDERLYING_WETH";
        underlyings[4] = "UNDERLYING_WBTC";
        underlyings[5] = "UNDERLYING_WBNB";
        uint256 length = underlyings.length;
        vm.startBroadcast(govPrivateKey);
        for (uint i; i < length;++i) {
            address underlying = vm.envAddress(underlyings[i]);
            if (i == 4 || i == 5) {
                Voter(voter).pushUnderlying(underlying);
            }
        }
        vm.stopBroadcast();
        
    }
}
