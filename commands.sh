RPC_URL=https://sepolia.base.org
PRIVATE_KEY=<PRIVATE_KEY>
ETHERSCAN_API_KEY=<ETHERSCAN_API_KEY>

# Deploy and Verify Contract
# Look up `forge` cmd documentation
# if you want to verify just add `--verify --verifier-url $ETHERSCAN_API_KEY`
forge create ModelRegistry --rpc-url $RPC_URL --private-key $PRIVATE_KEY
forge create NodeRegistry --rpc-url $RPC_URL --private-key $PRIVATE_KEY
NODE_REGISTRY_CONTRACT_ADDRESS=<NODE_REGISTRY_CONTRACT_ADDRESS>
forge create SessionManager --constructor-args <NODE_REGISTRY_CONTRACT_ADDRESS> --rpc-url <RPC_URL> --private-key <PRIVATE_KEY>

# Set Node IP Address
NODE_REGISTRY_CONTRACT_ADDRESS=<NODE_REGISTRY_CONTRACT_ADDRESS>
cast send $NODE_REGISTRY_CONTRACT_ADDRESS --rpc-url $RPC_URL --private-key $PRIVATE_KEY "setNodeIPAddress(uint256,string)" 1 "192.168.1.1"
