require("dotenv").config();
require("@openzeppelin/hardhat-upgrades");
require("@nomiclabs/hardhat-ethers");
require("@nomiclabs/hardhat-etherscan");
require("@nomiclabs/hardhat-waffle");
require("hardhat-contract-sizer");
require("hardhat-gas-reporter");
require("solidity-coverage");
require("hardhat-deploy");
const ethers = require("ethers");

require("./scripts/tasks");

const FORK_FUJI = process.env.FORK_FUJI == "true";
const FORK_MAINNET = process.env.FORK_MAINNET == "true";
const forkingData = FORK_FUJI
  ? {
      url: "https://api.avax-test.network/ext/bc/C/rpc",
    }
  : FORK_MAINNET
  ? {
      url: "https://api.avax.network/ext/bc/C/rpc",
    }
  : undefined;

let config = {
  solidity: {
    compilers: [
      {
        version: "0.8.7",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
    ],
  },
  defaultNetwork: "hardhat",
  networks: {
    hardhat: {
      deploy: ["./deploy/localhost"],
      chainId: forkingData ? 43112 : 43112, //Only specify a chainId if we are not forking
      gasPrice: 225000000000,
      forking: forkingData,
    },
    localhost: {
      url: "http://127.0.0.1:8545/",
      deploy: ["./deploy/localhost"],
      gasPrice: ethers.utils.parseUnits("100", "gwei").toNumber(),
      chainId: 43112,
      gas: 2100000,
    },
    fuji: {
      url: "https://api.avax-test.network/ext/bc/C/rpc",
      deploy: ["./deploy/fuji"],
      chainId: 43113,
      gasPrice: 30 * 1000000000,
    },
    mainnet: {
      url: "https://api.avax.network/ext/bc/C/rpc",
      deploy: ["./deploy/mainnet"],
      chainId: 43114,
      gasPrice: 40 * 1000000000,
    },
  },
  namedAccounts: {
    deployer: {
      default: 0, // here this will by default take the first account as deployer
      1: 0, // similarly on mainnet it will take the first account as deployer.
    },
    senate: {
      default: 1,
      0: 1,
    },
    ELECTOR: {
      default: 2,
      0: 2,
    },
  },
  paths: {
    sources: "./contracts",
    artifacts: "./build/artifacts",
    cache: "./build/cache",
  },
  etherscan: {
    apiKey: process.env.SNOWTRACE_API_KEY,
  },
};

if (process.env.ACCOUNT_PRIVATE_KEYS) {
  config.networks = {
    ...config.networks,
    fuji: {
      ...config.networks?.fuji,
      accounts: process.env.ACCOUNT_PRIVATE_KEYS.split(" "),
    },
    mainnet: {
      ...config.networks?.mainnet,
      accounts: process.env.ACCOUNT_PRIVATE_KEYS.split(" "),
    },
    localhost: {
      ...config.networks?.localhost,
      accounts: process.env.ACCOUNT_PRIVATE_KEYS.split(" "),
    },
  };
}
module.exports = config;
