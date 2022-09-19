const web3 = require("web3");
const func = async (taskArgs, hre) => {
  const { deployer } = await getNamedAccounts();
  const { deployments } = hre;
  const { execute, read } = deployments;
  try {
    id = taskArgs.id;
    if (taskArgs.name) {
      probID = await read("Portal", "getIdFromName", taskArgs.name);
      if (id) {
        if (id != probID)
          throw Error(
            "Id and name doesn't match, check again or provide only one"
          );
      }
      id = probID;
    }
    console.log("Tx sent...");

    await execute(
      "Portal",
      { from: deployer, log: true },
      "approveProposal",
      id
    );
    console.log(`created: ${id}`);
  } catch (error) {
    console.log(error);
    console.log("Unsuccesful approval...");
    console.log("try --network");
  }
};

module.exports = func;
