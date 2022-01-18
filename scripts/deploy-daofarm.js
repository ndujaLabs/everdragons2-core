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

  const DAOFarm = await ethers.getContractFactory("DAOFarm")
  const dAOFarm = await DAOFarm.deploy(everDragons2.address)
  await dAOFarm.deployed()
  console.log("DAOFarm deployed to:", dAOFarm.address);

  everDragons2.setManager(dAOFarm.address)

  console.log(`
To verify DAOFarm source code:
    
  npx hardhat verify --show-stack-traces \\
      --network ${network} \\
      ${dAOFarm.address}  \\
      ${everDragons2.address}
      
`)

  await deployUtils.saveDeployed(chainId, ['DAOFarm'], [dAOFarm.address])
}

main()
    .then(() => process.exit(0))
    .catch(error => {
      console.error(error);
      process.exit(1);
    });
