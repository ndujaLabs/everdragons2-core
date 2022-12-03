require('dotenv').config()
const hre = require("hardhat");
const ethers = hre.ethers
const {expect} = require("chai")
const _ = require('lodash');
const earners = require("./lib/goldbits-everdragons2.json")

const DeployUtils = require('./lib/DeployUtils')
const {cleanStruct} = require('../test/helpers');
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

  console.log("Account balance:", (await deployer.getBalance()).toString());
  console.log("Deploying GoldbitsEarnings")
  const Earnings = await ethers.getContractFactory("GoldbitsEarnings")
  const earnings = await Earnings.deploy()
  await earnings.deployed()

  let wallets = []
  let data = []
  for (let earner of _.clone(earners)) {
    wallets.push(earner.wallet);
    delete earner.wallet
    data.push(earner)
    if (data.length === 10) {
      await earnings.save(wallets, data)
      wallets = []
      data = []
    }
  }
  if (data.length > 0) {
    await earnings.save(wallets, data)
    for (let j=0;j< data.length;j++) {
      let saved = cleanStruct(await earnings.earnings(wallets[j]))
      expect(saved.goldbits).equal(data[j].goldbits)
    }
  }

  await earnings.freeze()

}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
    .then(() => process.exit(0))
    .catch(error => {
      console.error(error);
      process.exit(1);
    });

