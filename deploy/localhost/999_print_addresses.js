const func = async function (hre) {
  const { deployments } = hre;
  const { all } = deployments;

  const allContracts = await all();

  const arr = [];
  console.table(
    Object.keys(allContracts).map((k) => [k, allContracts[k].address])
  );
};
module.exports = func;
module.exports.tags = ["PrintAdresses"];
