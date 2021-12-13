require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-etherscan");
// require("hardhat-gas-reporter");

let env = require('./env.json');

if (process.env.GAS_REPORT === 'yes') {
  require("hardhat-gas-reporter");
}


// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async () => {
  const accounts = await ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  solidity: {
    version: '0.8.2',
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  networks: {
    hardhat: {
      blockGasLimit: 10000000,
    },
    localhost: {
      url: "http://localhost:8545"
    },
    ganache: {
      url: "http://localhost:7545"
    },
    rinkeby: {
      url: `https://rinkeby.infura.io/v3/${env.infuraApiKey}`,
      accounts: [env.privateKey]
    },
    goerli: {
      url: `https://goerli.infura.io/v3/${env.infuraApiKey}`,
      accounts: [env.privateKey]
    },
    ethereum: {
      url: `https://mainnet.infura.io/v3/${env.infuraApiKey}`,
      accounts: [env.privateKey]
    },
    bsc_testnet: {
      url: "https://data-seed-prebsc-1-s1.binance.org:8545",
      chainId: 97,
      gasPrice: 20000000000,
      accounts: [env.privateKey]
    },
    bsc: {
      url: "https://bsc-dataseed.binance.org/",
      chainId: 56,
      gasPrice: 20000000000,
      accounts: [env.privateKey]
    },
    mumbai: {
      url: "https://rpc-mumbai.matic.today/",
      chainId: 80001,
      gasPrice: 20000000000,
      accounts: [env.privateKey]
    },
    matic: {
      url: `https://rpc-mainnet.maticvigil.com/v1/${env.maticvigilKey}`,
      chainId: 137,
      gasPrice: 20000000000,
      accounts: [env.privateKey]
    },
  },
  etherscan: {
    apiKey: env.etherscanKey
    // apiKey: env.bscscanKey
  },
  gasReporter: {
    currency: 'USD',
    coinmarketcap: env.coinMarketCapAPIKey
  }
};

