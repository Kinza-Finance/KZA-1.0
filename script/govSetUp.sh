# !/bin/bash
# this is sequential in the initial deployment, after all contract creation
forge script script/gov-action/Minter-updateVoter.s.sol --rpc-url $RPC_URL --broadcast -vvvv
forge script script/gov-action/Minter-updateDistributor.s.sol --rpc-url $RPC_URL --broadcast -vvvv
forge script script/gov-action/XKZA-updateVoter.s.sol --rpc-url $RPC_URL --broadcast -vvvv
forge script script/gov-action/RewardsVault-updateTransferStrat.s.sol --rpc-url $RPC_URL --broadcast -vvvv
forge script script/gov-action/EDistributor-setVault.s.sol --rpc-url $RPC_URL --broadcast -vvvv
forge script script/gov-action/EDistributor-setEManager.s.sol --rpc-url $RPC_URL --broadcast -vvvv
forge script script/gov-action/EManager-setEmissionAdmin.s.sol --rpc-url $RPC_URL --broadcast -vvvv

forge script script/gov-action/KZA-initialMint.s.sol --rpc-url $RPC_URL --broadcast -vvvv
forge script script/gov-action/Voter-pushUnderlying.s.sol --rpc-url $RPC_URL --broadcast -vvvv