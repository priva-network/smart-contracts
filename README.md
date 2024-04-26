# Smart Contracts
A set of smart contracts that the Priva network uses.

Documentation can be found at https://priva.gitbook.io/priva

# Setup

1. Install Foundry development tools at https://book.getfoundry.sh/
2. It's useful to install the Solidity VSCode Extension
3. Run `forge build` to install dependencies and build contracts

# Run Locally

To run locally, you'll need to get a local blockchain running, and then use foundry cli tools to run commands against that chain.

Foundry should've installed the `anvil` CLI to run a local blockchain. All you need to do is run:
```bash
anvil
```

`commands.sh` has noted some common commands (like deploying contracts) that would be useful for reference.
