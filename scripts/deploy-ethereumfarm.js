require('dotenv').config()
const hre = require("hardhat");
const ethers = hre.ethers
const requireOrMock = require('require-or-mock')

const {
  initEthers,
  getTimestamp,
  normalize
} = require('../test/helpers')

const DeployUtils = require('./lib/DeployUtils')
let deployUtils

const deployed = requireOrMock('export/deployed.json')

async function main() {

  initEthers(ethers)
  deployUtils = new DeployUtils(ethers)
  const chainId = await deployUtils.currentChainId()
  let [deployer] = await ethers.getSigners();

  const network = chainId === 1 ? 'ethereum'
      : chainId === 42 ? 'kovan'
          : 'localhost'

  console.log(
      "Deploying contracts with the account:",
      deployer.address,
      'to', network
  );

  const EthereumFarm = await ethers.getContractFactory("EthereumFarm")
  const ethereumFarm = await EthereumFarm.deploy(process.env.VALIDATOR)
  await ethereumFarm.deployed()

  console.log(`
To verify GenesisFarm2 source code:
    
  npx hardhat verify --show-stack-traces \\
      --network ${network} \\
      ${ethereumFarm.address}  \\
      ${process.env.VALIDATOR}
      
`)

  await deployUtils.saveDeployed(chainId, ['EthereumFarm'], [ethereumFarm.address])
}

main()
    .then(() => process.exit(0))
    .catch(error => {
      console.error(error);
      process.exit(1);
    });
