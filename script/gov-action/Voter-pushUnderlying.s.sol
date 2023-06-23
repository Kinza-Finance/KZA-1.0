// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.17;

import "forge-std/Script.sol";
import "../../src/contracts/KZA/Voter.sol";
import "../../src/interfaces/IPoolDataProvider.sol";

contract VoterPushUnderlying is Script {
    function run() external {
        uint256 govPrivateKey = vm.envUint("PRIVATE_KEY_GOV");
        address voter = vm.envAddress("Voter");
        address dataProvider = vm.envAddress("PoolDataProvider");
        IPoolDataProvider.TokenData[] memory tokens = IPoolDataProvider(dataProvider).getAllReservesTokens();
    
        vm.startBroadcast(govPrivateKey);

        for (uint i; i < tokens.length;++i) {
            address underlying = tokens[i].tokenAddress;
            Voter(voter).pushUnderlying(underlying);
        }
        vm.stopBroadcast();
        
    }
}
