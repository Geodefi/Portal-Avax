const web3 = require("web3");

function delay(time) {
  return new Promise((resolve) => setTimeout(resolve, time));
}

const func = async (taskArgs, hre) => {
  /**
   * First do:
   * npx hardhat clean
   * npx hardhat compile
   * npx hardhat upgradePortal  --network """"""
   */
  const { deployer } = await getNamedAccounts();
  const { deployments } = hre;
  const { get, read, deploy } = deployments;
  try {
    testPortal = await ethers.getContractAt(
      "Portal",
      (
        await get("Portal")
      ).address
    );
    prevContractVersion = await read("Portal", "getVersion");

    // ensure you start from a fresh deployment for library deployments
    // put them here if needed
    console.log("DataStoreUtils:", (await get("DataStoreUtils")).address);
    console.log("GeodeUtils:", (await get("GeodeUtils")).address);
    console.log("StakeUtils:", (await get("StakeUtils")).address);
    await deploy("StakeUtils", {
      from: deployer,
      log: true,
      libraries: {
        DataStoreUtils: (await get("DataStoreUtils")).address,
      },
    });
    await deploy("GeodeUtils", {
      from: deployer,
      log: true,
      libraries: {
        DataStoreUtils: (await get("DataStoreUtils")).address,
      },
    });
    console.log("deployed the needed libraries:");
    console.log("DataStoreUtils:", (await get("DataStoreUtils")).address);
    console.log("GeodeUtils:", (await get("GeodeUtils")).address);
    console.log("StakeUtils:", (await get("StakeUtils")).address);

    let PortalFactory = await ethers.getContractFactory("Portal", {
      libraries: {
        DataStoreUtils: (await get("DataStoreUtils")).address,
        GeodeUtils: (await get("GeodeUtils")).address,
        StakeUtils: (await get("StakeUtils")).address,
      },
    });
    let testPortalV2 = await PortalFactory.deploy();
    await delay(5000);

    console.log("deployed the implementation", testPortalV2.address);
    _name = web3.utils.asciiToHex("V1.3");
    _id = await testPortal.getIdFromName("V1.3");

    await testPortal.newProposal(testPortalV2.address, 2, 100000, _name);
    await delay(6000);
    await testPortal.approveProposal(_id);
    await delay(6000);
    console.log("approved the update");

    await testPortal.upgradeTo(testPortalV2.address);
    await delay(5000);

    testPortal = await ethers.getContractAt("Portal", testPortal.address);
    console.log(
      "Portal upgraded to: ",
      testPortalV2.address,
      "version: ",
      (await testPortal.getVersion()).toString()
    );
  } catch (error) {
    console.log(error);
    console.log("Unsuccesful deployment...");
    console.log("try --network");
  }
};

module.exports = func;
