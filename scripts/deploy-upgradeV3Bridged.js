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

  const network = chainId === 1 ? 'ethereum' : chainId === 56 ? 'bsc' : 'localhost'

  console.log(
      "Deploying contracts with the account:",
      deployer.address,
      'to', network
  );

  console.log("Account balance:", (await deployer.getBalance()).toString());

  const Everdragons2GenesisBridged = await ethers.getContractFactory("Everdragons2GenesisBridged")
  const everdragons2GenesisBridged = Everdragons2GenesisBridged.attach(deployed[chainId].Everdragons2GenesisBridged)

  const Everdragons2GenesisBridgedV3 = await ethers.getContractFactory("Everdragons2GenesisBridgedV3")
  //
  // console.log("Importing")
  // await upgrades.forceImport(deployed[chainId].Everdragons2GenesisBridged, Everdragons2GenesisBridged);
  // process.exit()

  const upgraded = await upgrades.upgradeProxy(everdragons2GenesisBridged.address, Everdragons2GenesisBridgedV3);
  await upgraded.deployed();

  console.log("upgraded")
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
    .then(() => process.exit(0))
    .catch(error => {
      console.error(error);
      process.exit(1);
    });

