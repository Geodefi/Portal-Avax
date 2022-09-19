const func = async function (hre) {
  const { deployments, getNamedAccounts } = hre;
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  await deploy("gAVAX", {
    from: deployer,
    log: true,
    args: ["https://api.geode.fi/gavax"],
    skipIfAlreadyDeployed: true,
  });
};

module.exports = func;
module.exports.tags = ["gAVAX"];
