const CHAIN_ID = {
  MAINNET: "1",
  ROPSTEN: "3",
  GOERLI: "5",
  HARDHAT: "31337",
};

module.exports.CHAIN_ID = CHAIN_ID;

module.exports.isMainnet = function (networkId) {
  return (
    networkId == module.exports.CHAIN_ID.MAINNET ||
    networkId == module.exports.CHAIN_ID.ARBITRUM_MAINNET
  );
};

module.exports.isTestNetwork = function (networkId) {
  return (
    networkId == CHAIN_ID.HARDHAT ||
    networkId == CHAIN_ID.ROPSTEN ||
    networkId == CHAIN_ID.GOERLI
  );
};
