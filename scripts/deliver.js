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
  let [deployer] = await ethers.getSigners();

  const GenesisFarm3 = await ethers.getContractFactory("GenesisFarm3")
  const farm = GenesisFarm3.attach(deployed[chainId].GenesisFarm3)

  const tx = await farm.deliverCrossChainPurchase(
      process.env.NONCE,
      process.env.RECIPIENT,
      process.env.AMOUNT, {
        gasLimit: (80 + 140 * parseInt(process.env.AMOUNT)) * 1000,
      });

  // const money = chainId === 137 ? '1' : '0.1'
  //
  // await wallet.sendTransaction({
  //   to: process.env.RECIPIENT,
  //   value: ethers.utils.parseEther(money),
  // });
  //
  console.log(tx.hash)

}

main()
    .then(() => process.exit(0))
    .catch(error => {
      console.error(error);
      process.exit(1);
    });
