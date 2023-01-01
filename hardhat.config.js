require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-etherscan");
require('@openzeppelin/hardhat-upgrades');
// require("hardhat-gas-reporter");
const requireOrMock = require('require-or-mock')

require("dotenv").config();
require("cryptoenv").parse(() => process.env.NODE_ENV !== "test");

if (process.env.GAS_REPORT === 'yes') {
  require("hardhat-gas-reporter");
}

const {env} = process;

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
    version: '0.8.17',
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
    ropsten: {
      url: `https://ropsten.infura.io/v3/${env.INFURA_KEY}`,
      accounts: [env.FOR_TESTNET]
    },
    kovan: {
      url: `https://kovan.infura.io/v3/${env.INFURA_KEY}`,
      accounts: [env.FOR_TESTNET]
    },
    ethereum: {
      url: `https://mainnet.infura.io/v3/${env.INFURA_KEY}`,
      accounts: [env.NDUJA]
    },
    bsc_testnet: {
      url: "https://data-seed-prebsc-1-s1.binance.org:8545",
      chainId: 97,
      gasPrice: 20000000000,
      accounts: [env.FOR_TESTNET]
    },
    bsc: {
      url: "https://bsc-dataseed.binance.org",
      chainId: 56,
      gasPrice: 20000000000,
      accounts: [env.NDUJA]
    },
    mumbai: {
      url: "https://matic-mumbai.chainstacklabs.com",
      chainId: 80001,
      gasPrice: 20000000000,
      accounts: [env.USEMATICKEY ? env.maticKey : env.FOR_TESTNET]
    },
    matic: {
      url: `https://polygon-mainnet.infura.io/v3/${env.INFURA_KEY}`,
      chainId: 137,
      accounts: [env.USEMATICKEY ? env.maticKey : env.NDUJA]
    },
    alfajores: {
      url: "https://alfajores-forno.celo-testnet.org",
      accounts: [env.FOR_TESTNET],
      chainId: 44787,
    },
  },
  etherscan: {
    // apiKey: env.etherscanKey
    apiKey: env.polygonscanAPIKey
    // apiKey: env.bscscanKey
  },
  gasReporter: {
    currency: 'USD',
    coinmarketcap: env.coinMarketCapAPIKey
  }
};

