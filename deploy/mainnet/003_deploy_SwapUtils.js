const func = async function (hre) {
  const { deployments, getNamedAccounts } = hre;
  const { deploy, get } = deployments;
  const { deployer } = await getNamedAccounts();

  await deploy("SwapUtils", {
    from: deployer,
    log: true,
    skipIfAlreadyDeployed: true,
  });
};
module.exports = func;
module.exports.tags = ["SwapUtils"];
