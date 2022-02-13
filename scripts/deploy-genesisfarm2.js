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

  const network = chainId === 137 ? 'matic'
      : chainId === 80001 ? 'mumbai'
          : 'localhost'

  if (!deployed[chainId]) {
    console.error('Everdragons2Genesis not deployed on', network)
    process.exit(1)
  }

  console.log(
      "Deploying contracts with the account:",
      deployer.address,
      'to', network
  );

  const Everdragons2Genesis = await ethers.getContractFactory("Everdragons2Genesis")
  const everdragons2Genesis = Everdragons2Genesis.attach(deployed[chainId].Everdragons2Genesis)

  const GenesisFarm2 = await ethers.getContractFactory("GenesisFarm2")

  const price = network === 'matic' ? normalize(100) : '50000000000000000'

  const genesisFarm2 = await GenesisFarm2.deploy(
      everdragons2Genesis.address,
      650,
      350,
      price,
      4
  )
  console.log("Deploying GenesisFarm2");
  await genesisFarm2.deployed()
  console.log("GenesisFarm2 deployed to:", genesisFarm2.address);

  await everdragons2Genesis.setManager(genesisFarm2.address)

  console.log(`
To verify GenesisFarm2 source code:
    
  npx hardhat verify --show-stack-traces \\
      --network ${network} \\
      ${genesisFarm2.address}  \\
      ${everdragons2Genesis.address} \\
      650 \\
      350 \\
      ${price} \\
      4
      
`)

  await deployUtils.saveDeployed(chainId, ['GenesisFarm2'], [genesisFarm2.address])
}

main()
    .then(() => process.exit(0))
    .catch(error => {
      console.error(error);
      process.exit(1);
    });
