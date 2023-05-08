const Web3 = require('web3');
const fs = require('fs');
const dotenv = require('dotenv');

dotenv.config();

const web3 = new Web3(new Web3.providers.HttpProvider(`https://goerli.infura.io/v3/${process.env.INFURA_PROJECT_ID_GOERLI}`));

const migrationsABI = JSON.parse(fs.readFileSync('build/contracts/Migrations.json', 'utf8')).abi;
const migrationsBytecode = JSON.parse(fs.readFileSync('build/contracts/Migrations.json', 'utf8')).bytecode;

async function estimateGas() {
  const account = web3.eth.accounts.privateKeyToAccount(process.env.PRIVATE_KEY);
  web3.eth.accounts.wallet.add(account);
  web3.eth.defaultAccount = account.address;

  const migrationsContract = new web3.eth.Contract(migrationsABI);

  try {
    const gasEstimate = await migrationsContract.deploy({ data: migrationsBytecode }).estimateGas();
    console.log("Estimated gas for deploying Migrations contract:", gasEstimate);
  } catch (error) {
    console.error("Error estimating gas:", error);
  }
}

estimateGas();
