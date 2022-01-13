require('dotenv').config()
const hre = require("hardhat");
const ethers = hre.ethers

const DeployUtils = require('./lib/DeployUtils')
let deployUtils

async function main() {
  deployUtils = new DeployUtils(ethers)

  const chainId = await deployUtils.currentChainId()
  let [deployer] = await ethers.getSigners();

  const network = chainId === 137 ? 'matic'
      : chainId == 80001 ? 'mumbai'
          // for now:
          : 'localhost'

  const secondaryChain = chainId !== 137 && chainId !== 80001 && chainId !== 1337

  console.log(
      "Deploying contracts with the account:",
      deployer.address
  );

  console.log("Account balance:", (await deployer.getBalance()).toString());

  Everdragons2 = await ethers.getContractFactory("Everdragons2")
  everDragons2 = await upgrades.deployProxy(Everdragons2, [10001, secondaryChain])
  await everDragons2.deployed()
  console.log("Everdragons2 deployed to:", everDragons2.address);

  console.log(`
To verify Everdragons2 source code:
    
  npx hardhat verify --show-stack-traces \\
      --network ${network} \\
      ${everDragons2.address}
      
`)

  await deployUtils.saveDeployed(chainId, ['Everdragons2'], [everDragons2.address])

}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });

