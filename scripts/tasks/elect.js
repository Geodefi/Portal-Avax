const web3 = require("web3");
const func = async (taskArgs, hre) => {
  const { ELECTOR } = await getNamedAccounts();
  const { deployments } = hre;
  const { execute, read } = deployments;
  try {
    console.log("Tx sent...");
    await execute(
      "Portal",
      { from: ELECTOR, log: true },
      "approveSenate",
      taskArgs.sid,
      taskArgs.pid
    );
    pname = await read("Portal", "getNameFromId", taskArgs.pid);
    stt = await read("Portal", "getProposal", taskArgs.sid);
    console.log(stt);
    console.log(`sucessfully voted for: ${web3.utils.toAscii(pname)}`);
  } catch (error) {
    console.log(error);
    console.log("Unsuccesful approval...");
    console.log("try --network");
  }
};

module.exports = func;
