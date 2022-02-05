require('dotenv').config()
const hre = require("hardhat");
const ethers = hre.ethers
const requireOrMock = require('require-or-mock')

const DeployUtils = require('./lib/DeployUtils')
let deployUtils

const deployed = requireOrMock('export/deployed.json')

async function main() {

  deployUtils = new DeployUtils(ethers)
  const chainId = await deployUtils.currentChainId()
  let [, , localSuperAdmin] = await ethers.getSigners();

  const network = chainId === 137 ? 'matic'
      : chainId == 80001 ? 'mumbai'
          : 'localhost'

  if (!deployed[chainId]) {
    console.error('Everdragons2 not deployed on', network)
    process.exit(1)
  }

  const Everdragons2 = await ethers.getContractFactory("Everdragons2")
  const everDragons2 = Everdragons2.attach(deployed[chainId].Everdragons2)

  const GenesisFarm = await ethers.getContractFactory("GenesisFarm")
  const genesisFarm = await GenesisFarm.deploy(everDragons2.address)
  await genesisFarm.deployed()
  console.log("GenesisFarm deployed to:", genesisFarm.address);

  everDragons2.setManager(genesisFarm.address)

  console.log(`
To verify GenesisFarm source code:
    
  npx hardhat verify --show-stack-traces \\
      --network ${network} \\
      ${genesisFarm.address}  \\
      ${everDragons2.address}
      
`)

  await deployUtils.saveDeployed(chainId, ['GenesisFarm'], [genesisFarm.address])
}

main()
    .then(() => process.exit(0))
    .catch(error => {
      console.error(error);
      process.exit(1);
    });
