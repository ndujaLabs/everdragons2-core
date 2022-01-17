const path = require('path');
const fs = require('fs-extra');
const {Contract} = require('@ethersproject/contracts')

class DeployUtils {

  constructor(ethers) {
    this.ethers = ethers
  }

  async sleep(millis) {
    // eslint-disable-next-line no-undef
    return new Promise((resolve) => setTimeout(resolve, millis));
  }

  getProviders() {
    const {INFURA_API_KEY} = process.env

    const rpc = url => {
      return new this.ethers.providers.JsonRpcProvider(url)
    }

    let providers = {
      1337: this.ethers.getDefaultProvider('http://localhost:8545'),
    }

    if (INFURA_API_KEY) {
      providers = Object.assign(providers, {
        1: rpc(`https://mainnet.infura.io/v3/${INFURA_API_KEY}`),
        3: rpc(`https://ropsten.infura.io/v3/${INFURA_API_KEY}`),
        4: rpc(`https://rinkeby.infura.io/v3/${INFURA_API_KEY}`),
        5: rpc(`https://goerli.infura.io/v3/${INFURA_API_KEY}`)
      })
    }

    return providers

  }

  async getABI(name, folder) {
    const fn = path.resolve(__dirname, `../../artifacts/contracts/${folder}/${name}.sol/${name}.json`)
    if (fs.pathExists(fn)) {
      return JSON.parse(await fs.readFile(fn, 'utf8')).abi
    }
  }

  async getContract(name, folder, address, chainId) {
    return new Contract(address, await this.getABI(name, folder), this.getProviders()[chainId])
  }

  async currentChainId() {
    return (await this.ethers.provider.getNetwork()).chainId
  }

  async saveDeployed(chainId, names, addresses, extras) {
    if (names.length !== addresses.length) {
      throw new Error('Inconsistent arrays')
    }
    const deployedJson = path.resolve(__dirname, '../../export/deployed.json')
    if (!(await fs.pathExists(deployedJson))) {
      await fs.ensureDir(path.dirname(deployedJson))
      await fs.writeFile(deployedJson, '{}')
    }
    const deployed = JSON.parse(await fs.readFile(deployedJson, 'utf8'))
    if (!deployed[chainId]) {
      deployed[chainId] = {}
    }
    const data = {}
    for (let i=0;i<names.length;i++) {
      data[names[i]] = addresses[i]
    }
    deployed[chainId] = Object.assign(deployed[chainId], data)

    if (extras) {
      // data needed for verifications
      if (!deployed.extras) {
        deployed.extras = {}
      }
      if (!deployed.extras[chainId]) {
        deployed.extras[chainId] = {}
      }
      deployed.extras[chainId] = Object.assign(deployed.extras[chainId], extras)
    }
    // console.log(deployed)
    await fs.writeFile(deployedJson, JSON.stringify(deployed, null, 2))
  }

}

module.exports = DeployUtils
