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
  let [, , localSuperAdmin] = await ethers.getSigners();

  const network = chainId === 137 ? 'matic'
      : chainId == 80001 ? 'mumbai'
          : 'localhost'

  if (!deployed[chainId]) {
    console.error('Everdragons2Genesis not deployed on', network)
    process.exit(1)
  }

  const Everdragons2Genesis = await ethers.getContractFactory("Everdragons2Genesis")
  const everdragons2Genesis = Everdragons2Genesis.attach(deployed[chainId].Everdragons2Genesis)

  const GenesisFarm = await ethers.getContractFactory("GenesisFarm")

  const price = normalize(network === 'matic' ? 500 : 0.1)
  const delay = network === 'matic' ? 3600 : 10

  const genesisFarm = await GenesisFarm.deploy(
      everdragons2Genesis.address,
      250,
      600,
      price,
      // sale start after one hour
      (await getTimestamp()) + delay
  )
  await genesisFarm.deployed()
  console.log("GenesisFarm deployed to:", genesisFarm.address);

  everdragons2Genesis.setManager(genesisFarm.address)

  console.log(`
To verify GenesisFarm source code:
    
  npx hardhat verify --show-stack-traces \\
      --network ${network} \\
      ${genesisFarm.address}  \\
      ${everdragons2Genesis.address}
      
`)

  await deployUtils.saveDeployed(chainId, ['GenesisFarm'], [genesisFarm.address])
}

main()
    .then(() => process.exit(0))
    .catch(error => {
      console.error(error);
      process.exit(1);
    });
