const web3 = require("web3");
const func = async (taskArgs, hre) => {
  types = {
    senate: 1,
    upgrade: 2,
    operator: 4,
    planet: 5,
  };
  const { deployer } = await getNamedAccounts();
  const { deployments } = hre;
  const { execute, read } = deployments;
  try {
    if (!types[taskArgs.type]) throw Error("type should be one of defined");
    console.log("Tx sent...");
    id = await read("Portal", "getIdFromName", taskArgs.name);
    await execute(
      "Portal",
      { from: deployer, log: true },
      "newProposal",
      taskArgs.controller,
      types[taskArgs.type],
      7 * 24 * 60 * 60 - 1,
      web3.utils.asciiToHex(taskArgs.name)
    );
    console.log(`new ${taskArgs.type} proposal: ${id}`);
  } catch (error) {
    console.log(error);
    console.log("Unsuccesful proposal...");
    console.log("try --network");
  }
};

module.exports = func;
