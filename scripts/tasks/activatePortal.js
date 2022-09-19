const func = async (taskArgs, hre) => {
  const { deployer } = await getNamedAccounts();
  const { deployments } = hre;
  const { execute, get } = deployments;
  try {
    console.log("Tx sent...");
    await execute(
      "gAVAX",
      { from: deployer, log: true },
      "updateMinterPauserOracle",
      (
        await get("Portal")
      ).address
    );
    console.log("Portal is now gAVAX minter");
  } catch (error) {
    console.log(error);
    console.log("Unsuccesful...");
    console.log("try --network");
  }
};

module.exports = func;
