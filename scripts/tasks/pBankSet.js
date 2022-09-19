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
      "setPBank",
      taskArgs.oid,
      taskArgs.pid,
      web3.utils.asciiToHex(taskArgs.bank)
    );
    oname = await read("Portal", "getNameFromId", taskArgs.oid);
    pname = await read("Portal", "getNameFromId", taskArgs.pid);
    console.log(
      `sucessfully set pBank for operator: ${web3.utils.toAscii(
        oname
      )} for planet: ${web3.utils.toAscii(pname)} as: ${web3.utils.hexToAscii(
        await read("Portal", "getPBank", taskArgs.oid, taskArgs.pid)
      )}`
    );
  } catch (error) {
    console.log(error);
    console.log("Unsuccesful...");
    console.log("try --network");
  }
};

module.exports = func;
