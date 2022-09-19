const { upgrades } = require("hardhat");
const func = async function (hre) {
  const { deployments, getNamedAccounts, getChainId } = hre;
  const { get, save } = deployments;
  const { deployer } = await getNamedAccounts();

  const gAVAX = (await get("gAVAX")).address;
  const Swap = (await get("Swap")).address;
  const ERC20InterfaceUpgradable = (await get("ERC20InterfaceUpgradable"))
    .address;
  const LPToken = (await get("LPToken")).address;

  const Portal = await ethers.getContractFactory("Portal", {
    libraries: {
      DataStoreUtils: (await get("DataStoreUtils")).address,
      GeodeUtils: (await get("GeodeUtils")).address,
      StakeUtils: (await get("StakeUtils")).address,
    },
  });

  const proxy = await upgrades.deployProxy(
    Portal,
    [deployer, deployer, gAVAX, Swap, ERC20InterfaceUpgradable, LPToken],
    {
      kind: "uups",
      unsafeAllow: ["external-library-linking"],
    }
  );

  const artifact = await deployments.getExtendedArtifact("Portal");

  await save("Portal", {
    address: proxy.address,
    ...artifact,
  });
};

module.exports = func;
module.exports.tags = ["Portal"];
