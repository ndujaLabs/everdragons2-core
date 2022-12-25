require('dotenv').config()
const hre = require("hardhat");
const ethers = hre.ethers
const {expect} = require("chai")
const _ = require('lodash');
const earners = require("./lib/goldbits-everdragons2.json")

const envJs = require("../env")

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

  let provider = chainId === 137
      ? new ethers.providers.InfuraProvider(137, envJs.infuraApiKey)
      : new ethers.providers.JsonRpcProvider(chainId === 80001
          ? "https://matic-mumbai.chainstacklabs.com"
          :  "http://localhost:8545"
  );

  console.log("Deploying by", deployer.address)
  console.log("Account balance:", (await deployer.getBalance()).toString());

  console.log("Deploying GoldbitsEarnings")

  let feeData = await provider.getFeeData()
  let gasPrice = feeData.gasPrice.mul(105).div(100);
  if (gasPrice.div(1e9).toNumber() < 300 && chainId === 80001) {
    gasPrice = ethers.BigNumber.from("300000000000");
  }

  const Earnings = await ethers.getContractFactory("GoldbitsEarnings")
  const earnings = await Earnings.deploy({gasPrice})
  await earnings.deployed()
  console.log("Deployed to", earnings.address)

  let wallets = []
  let data = []
  for (let earner of _.clone(earners)) {
    wallets.push(earner.wallet);
    delete earner.wallet
    data.push(earner)
    if (data.length === 10) {
      await earnings.save(wallets, data, {
        gasLimit: 540000,
        gasPrice
      })
      wallets = []
      data = []
    }
  }
  if (data.length > 0) {
    await earnings.save(wallets, data, {
      gasLimit: 540000, gasPrice
    })
  }
  console.log(await earnings.total(), "should be 67 :-)")
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

