const BN = require("bignumber.js");
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
      "setMaintainerFee",
      taskArgs.id,
      BN(taskArgs.fee).toString()
    );
    pname = await read("Portal", "getNameFromId", taskArgs.id);
    console.log(web3.utils.toAscii(pname));
    console.log(
      `sucessfully set fee for: ${web3.utils.toAscii(pname)} as  ${await read(
        "Portal",
        "getMaintainerFeeFromId",
        taskArgs.id
      )}`
    );
  } catch (error) {
    console.log(error);
    console.log("Unsuccesful...");
    console.log("try --network");
  }
};

module.exports = func;
