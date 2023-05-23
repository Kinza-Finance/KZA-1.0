# !/bin/bash
# if verification fails run:
# forge verify-contract <address> ContractName --verifier-url $VERIFIER_URL --etherscan-api-key $ETHERSCAN_API_KEY
chainId=80001
forge script script/0-KZA.s.sol --rpc-url $MUMBAI_RPC_URL --broadcast --verify -vvvv
#source address of KZA into env variable
KZA=($(jq -r '.transactions[0].contractAddress' broadcast/0-KZA.s.sol/${chainId}/run-latest.json))
echo "\n#deployment variables\nKZA=$KZA" >> ".env"
# deploy XKZA
forge script script/1-XKZA.s.sol --rpc-url $MUMBAI_RPC_URL --broadcast --verify -vvvv
XKZA=($(jq -r '.transactions[0].contractAddress' broadcast/1-XKZA.s.sol/${chainId}/run-latest.json))
echo "XKZA=$XKZA" >> ".env"
# deploy vestingEscorow
forge script script/2-VestingEscrow.s.sol --rpc-url $MUMBAI_RPC_URL --broadcast --verify -vvvv
VestingEscrow=($(jq -r '.transactions[0].contractAddress' broadcast/2-VestingEscrow.s.sol/${chainId}/run-latest.json))
echo "VestingEscrow=$VestingEscrow" >> ".env"
# deploy minter
forge script script/3-Minter.s.sol --rpc-url $MUMBAI_RPC_URL --broadcast --verify -vvvv
Minter=($(jq -r '.transactions[0].contractAddress' broadcast/3-Minter.s.sol/${chainId}/run-latest.json))
echo "Minter=$Minter" >> ".env"
# deploy VoteLogic
forge script script/4-VoteLogic.s.sol --rpc-url $MUMBAI_RPC_URL --broadcast --verify -vvvv
VoteLogic=($(jq -r '.transactions[0].contractAddress' broadcast/4-VoteLogic.s.sol/${chainId}/run-latest.json))
echo "VoteLogic=$VoteLogic" >> ".env"
# deploy BribeAssetRegistry
forge script script/5-BribeAssetRegistry.s.sol --rpc-url $MUMBAI_RPC_URL --broadcast --verify -vvvv
BribeAssetRegistry=($(jq -r '.transactions[0].contractAddress' broadcast/5-BribeAssetRegistry.s.sol/${chainId}/run-latest.json))
echo "BribeAssetRegistry=$BribeAssetRegistry" >> ".env"
# deploy Voter
forge script script/6-Voter.s.sol --rpc-url $MUMBAI_RPC_URL --broadcast --verify -vvvv
Voter=($(jq -r '.transactions[0].contractAddress' broadcast/6-Voter.s.sol/${chainId}/run-latest.json))
echo "Voter=$Voter" >> ".env"
# deploy KZADistributor
forge script script/7-KZADistributor.s.sol --rpc-url $MUMBAI_RPC_URL --broadcast --verify -vvvv
KZADistributor=($(jq -r '.transactions[0].contractAddress' broadcast/7-KZADistributor.s.sol/${chainId}/run-latest.json))
echo "KZADistributor=$KZADistributor" >> ".env"
# deploy ReserveFeeDistributor
forge script script/8-ReserveFeeDistributor.s.sol --rpc-url $MUMBAI_RPC_URL --broadcast --verify -vvvv
ReserveFeeDistributor=($(jq -r '.transactions[0].contractAddress' broadcast/8-ReserveFeeDistributor.s.sol/${chainId}/run-latest.json))
echo "ReserveFeeDistributor=$ReserveFeeDistributor" >> ".env"
# deploy RewardsVault
forge script script/9-RewardsVault.s.sol --rpc-url $MUMBAI_RPC_URL --broadcast --verify -vvvv
RewardsVault=($(jq -r '.transactions[0].contractAddress' broadcast/9-RewardsVault.s.sol/${chainId}/run-latest.json))
echo "RewardsVault=$RewardsVault" >> ".env"
# deploy LockTransferStrategy
forge script script/10-LockTransferStrategy.s.sol --rpc-url $MUMBAI_RPC_URL --broadcast --verify -vvvv
LockTransferStrategy=($(jq -r '.transactions[0].contractAddress' broadcast/10-LockTransferStrategy.s.sol/${chainId}/run-latest.json))
echo "LockTransferStrategy=$LockTransferStrategy" >> ".env"

