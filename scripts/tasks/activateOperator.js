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
      "activateOperator",
      taskArgs.pid,
      taskArgs.oid
    );
    pname = await read("Portal", "getNameFromId", taskArgs.pid);
    oname = await read("Portal", "getNameFromId", taskArgs.oid);
    console.log(
      `sucessfully activated ${web3.utils.toAscii(
        oname
      )} for  ${web3.utils.toAscii(pname)}`
    );
  } catch (error) {
    console.log(error);
    console.log("Unsuccesful approval...");
    console.log("try --network");
  }
};

module.exports = func;
