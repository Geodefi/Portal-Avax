const web3 = require("web3");
const func = async (taskArgs, hre) => {
  const { deployer } = await getNamedAccounts();
  const { deployments } = hre;
  const { execute, read } = deployments;
  try {
    console.log("Tx sent...");
    await execute(
      "Portal",
      { from: deployer, log: true },
      "changeIdMaintainer",
      taskArgs.id,
      taskArgs.m
    );
    pname = await read("Portal", "getNameFromId", taskArgs.id);
    console.log(
      `sucessfully changed maintainer for: ${web3.utils.toAscii(pname)}`
    );
  } catch (error) {
    console.log(error);
    console.log("Unsuccesful approval...");
    console.log("try --network");
  }
};

module.exports = func;
