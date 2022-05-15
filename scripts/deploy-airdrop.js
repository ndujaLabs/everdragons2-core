require('dotenv').config()
const hre = require("hardhat");
const ethers = hre.ethers
const {expect} = require("chai")
const deployed = require("../export/deployed.json");
const whitelist = require("../test/fixtures/whitelist.json");

const DeployUtils = require('./lib/DeployUtils')
let deployUtils

async function main() {
  deployUtils = new DeployUtils(ethers)

  const chainId = await deployUtils.currentChainId()
  let [deployer] = await ethers.getSigners();

  const network = chainId === 80001 ? 'mumbai' : 'localhost'


  if (chainId !== 80001 && chainId !== 1337) {
    process.exit();
  }

  // const secondaryChain = chainId !== 137 && chainId !== 80001 && chainId !== 1337

  console.log(
      "Deploying contracts with the account:",
      deployer.address,
      'to', network
  );

  console.log("Account balance:", (await deployer.getBalance()).toString());

  const Everdragons2Genesis = await ethers.getContractFactory("Everdragons2GenesisV2Mumbai")
  const everdragons2Genesis = Everdragons2Genesis.attach(deployed[chainId].Everdragons2Genesis)

  // await (await everdragons2Genesis.airdrop(["0xdC3Ad42f950F12e7DbAD469267F9e48623637A31"], [1235])).wait()


  let k = 0
  let addresses = []
  let tokenIds = []
  for (let i = 0; i< whitelist.length; i++) {

    console.log("Whoops")
    process.exit()
    let elem = whitelist[i];
    for (let j=0;j< elem.tokenIds.length; j++) {
      // expect(await everdragons2Genesis.ownerOf(elem.tokenIds[j])).equal(elem.address)
      addresses.push(elem.address)
      tokenIds.push(elem.tokenIds[j])
    }
    // console.log("ok")
    // process.exit()
    if (addresses.length > 20 || i === whitelist.length - 1) {
      console.log("Airdropping: ", tokenIds)
      await (await everdragons2Genesis.airdrop(addresses, tokenIds)).wait()
      addresses = []
      tokenIds = []
    }
  }

  // everdragons2Genesis = await upgrades.upgradeProxy('0xE37760c7933176679951A5328a5Cd11fa800c60b', Everdragons2Genesis);

  // await everdragons2Genesis.deployed()
  // console.log("Everdragons2Genesis deployed to:", everdragons2Genesis.address);

//   console.log(`
// To verify Everdragons2Genesis source code:
//
//   npx hardhat verify --show-stack-traces \\
//       --network ${network} \\
//       ${everdragons2Genesis.address}
//
// `)

  // await deployUtils.saveDeployed(chainId, ['Everdragons2Genesis'], [everdragons2Genesis.address])

}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });

