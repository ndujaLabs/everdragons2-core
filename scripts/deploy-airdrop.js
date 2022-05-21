require('dotenv').config()
const hre = require("hardhat");
const ethers = hre.ethers
const {expect} = require("chai")
const deployed = require("../export/deployed.json");
const whitelist = require("./whitelist.js");

const DeployUtils = require('./lib/DeployUtils')
let deployUtils

async function main() {
  deployUtils = new DeployUtils(ethers)

  const chainId = await deployUtils.currentChainId()
  let [deployer] = await ethers.getSigners();

  const network =
      chainId === 80001 ? 'mumbai'
          : chainId === 137 ? 'matic'
              : chainId === 1337 ? 'localhost'
                  : null


  if (!network) {
    console.log("Unsupported network");
    process.exit();
  }

  // const secondaryChain = chainId !== 137 && chainId !== 80001 && chainId !== 1337

  console.log(
      "Airdropping with this address:",
      deployer.address,
      'to', network
  );

  console.log("Account balance:", (await deployer.getBalance()).toString());

  const Everdragons2Genesis = await ethers.getContractFactory(
      chainId === 137 ? "Everdragons2GenesisV2" : "Everdragons2GenesisV2Mumbai"
  )
  const everdragons2Genesis = Everdragons2Genesis.attach(deployed[chainId].Everdragons2Genesis)

  let addresses = []
  let tokenIds = []
  for (let i = 0; i < whitelist.length; i++) {
    let elem = whitelist[i];
    for (let j = 0; j < elem.tokenIds.length; j++) {
      addresses.push(elem.address)
      tokenIds.push(elem.tokenIds[j])
    }
    if (addresses.length >= 20 || i === whitelist.length - 1) {
      console.log("Airdropping: ", tokenIds)
      let tx = await everdragons2Genesis.airdrop(addresses, tokenIds, {
        gasLimit: 3000000
      })
      console.log("tx:", tx.hash)
      await tx.wait()
      addresses = []
      tokenIds = []
    }
  }
  addresses = []
  tokenIds = []
  const everdragons2Eth = "0xC2D5AD847dB63dF5434B9F148F37C8fE8173C03c"
  for (let i = 538; i <= 600; i++) {
    addresses.push(everdragons2Eth)
    tokenIds.push(i)
    if (addresses.length >= 20 || i === 600) {
      console.log("Airdropping: ", tokenIds)
      let tx = await everdragons2Genesis.airdrop(addresses, tokenIds, {
        gasLimit: 3000000
      })
      console.log("tx:", tx.hash)
      await tx.wait()
      addresses = []
      tokenIds = []
    }
  }
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
    .then(() => process.exit(0))
    .catch(error => {
      console.error(error);
      process.exit(1);
    });

