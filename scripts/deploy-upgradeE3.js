require('dotenv').config()
const hre = require("hardhat");
const ethers = hre.ethers
const deployed = require("../export/deployed.json");

const DeployUtils = require('./lib/DeployUtils')
let deployUtils

async function main() {
  deployUtils = new DeployUtils(ethers)

  const chainId = await deployUtils.currentChainId()
  let [deployer] = await ethers.getSigners();

  const network = chainId === 137 ? 'matic' : 'localhost'

  if (chainId !== 137 && chainId !== 1337) {
    process.exit();
  }

  console.log(
      "Deploying contracts with the account:",
      deployer.address,
      'to', network
  );

  console.log("Account balance:", (await deployer.getBalance()).toString());

  const Everdragons2Genesis = await ethers.getContractFactory("Everdragons2GenesisV3")
  const everdragons2Genesis = Everdragons2Genesis.attach(deployed[chainId].Everdragons2Genesis)

  const Everdragons2GenesisV3 = await ethers.getContractFactory("Everdragons2GenesisV3")

  await upgrades.forceImport(deployed[chainId].Everdragons2Genesis, Everdragons2Genesis);

  const upgraded = await upgrades.upgradeProxy(everdragons2Genesis.address, Everdragons2GenesisV3);
  await upgraded.deployed();

}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
    .then(() => process.exit(0))
    .catch(error => {
      console.error(error);
      process.exit(1);
    });

