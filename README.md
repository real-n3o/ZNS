# zNS v3

## Running Tests

```bash
# Install Truffle and ganache-cli
npm install -g truffle ganache-cli

# Install OpenZeppelin 
npm install --save @openzeppelin/contracts
npm install --save @openzeppelin/contracts-upgradeable

# Install Web3
npm install --save web3

# Run ganache-cli locally on port 8545 and host "127.0.0.1" on the development network
ganache-cli --port 8545 --host 127.0.0.1 -d

# Compile contracts with Truffle
truffle compile

# Run Truffle tests
truffle test

```

## License
This project is licensed under the MIT License.