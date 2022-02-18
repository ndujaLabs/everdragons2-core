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

  const price = ethers.utils.parseEther((chainId === 137 ? 100 : 0.1).toString())

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

  const GenesisFarm3 = await ethers.getContractFactory("GenesisFarm3")

  const genesisFarm3 = await GenesisFarm3.deploy(
      everdragons2Genesis.address,
      650,
      350,
      price,
      process.env.VALIDATOR
  )
  console.log("Deploying GenesisFarm3");
  await genesisFarm3.deployed()
  console.log("GenesisFarm3 deployed to:", genesisFarm3.address);

  await (await everdragons2Genesis.setManager(genesisFarm3.address)).wait()

  console.log(`
To verify GenesisFarm3 source code:
    
  npx hardhat verify --show-stack-traces \\
      --network ${network} \\
      ${genesisFarm3.address}  \\
      ${everdragons2Genesis.address} \\
      650 \\
      350 \\
      ${price} \\
      ${process.env.VALIDATOR}    
`)

  await deployUtils.saveDeployed(chainId, ['GenesisFarm3'], [genesisFarm3.address])
}

main()
    .then(() => process.exit(0))
    .catch(error => {
      console.error(error);
      process.exit(1);
    });
