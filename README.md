# zNS v3

## Running Tests

To run tests for this project, you will need to install Truffle and ganache-cli, as well as OpenZeppelin and OpenZeppelin Upgradeability.

```bash
# Install Truffle and ganache-cli
npm install -g truffle ganache-cli

# Install OpenZeppelin
npm install --save @openzeppelin/contracts

# Run ganache-cli locally on port 8545 and host "127.0.0.1" on the development network
ganache-cli --port 8545 --host 127.0.0.1 -d

# Compile contracts with Truffle
truffle compile

# Run Truffle tests
truffle test

License
This project is licensed under the MIT License.