const web3 = require("web3");
const BN = require("bignumber.js");
const func = async (taskArgs, hre) => {
  const { deployments } = hre;
  const { read } = deployments;
  try {
    console.log(`GOVERNANCE: ${await read("Portal", "getGovernance")}`);
    console.log(`SENATE: ${await read("Portal", "getSenate")}`);
    var ex = await read("Portal", "getSenateExpireTimestamp");
    var date = new Date(ex * 1000);
    console.log(`SenateExpireTimestamp:, ${date}`);
    params = await read("Portal", "getStakePoolParams");
    const {
      gAVAX,
      DEFAULT_SWAP_POOL,
      DEFAULT_LP_TOKEN,
      ORACLE,
      DEFAULT_A,
      DEFAULT_FEE,
      DEFAULT_ADMIN_FEE,
      FEE_DENOMINATOR,
      PERIOD_PRICE_INCREASE_LIMIT,
      MAX_MAINTAINER_FEE,
    } = params;
    console.log({
      gAVAX,
      DEFAULT_SWAP_POOL,
      DEFAULT_LP_TOKEN,
      ORACLE,
      DEFAULT_A_: DEFAULT_A.toString(),
      DEFAULT_FEE_: DEFAULT_FEE.toString(),
      DEFAULT_ADMIN_FEE_: DEFAULT_ADMIN_FEE.toString(),
      FEE_DENOMINATOR_: FEE_DENOMINATOR.toString(),
      PERIOD_PRICE_INCREASE_LIMIT: PERIOD_PRICE_INCREASE_LIMIT.toString(),
      MAX_MAINTAINER_FEE_: MAX_MAINTAINER_FEE.toString(),
    });

    var allPlanets = await read("Portal", "getIdsByType", 5);
    pd = await Promise.all(
      allPlanets.map(async (k) => [
        web3.utils.toAscii(await read("Portal", "getNameFromId", k)),
        `id: ${k.toString().substring(0, 8)}`,
        `Maintainer: ${await read("Portal", "getMaintainerFromId", k)}`,
        `fee: ${(await read("Portal", "getMaintainerFeeFromId", k))
          .mul(100)
          .div(FEE_DENOMINATOR)
          .toString()}%`,
        `ERC20:${await read("Portal", "planetCurrentInterface", k)}`,
        `Withdrawal Pool:${await read("Portal", "planetWithdrawalPool", k)}`,
        `WP LP token:${await read("Portal", "planetLPToken", k)}`,
      ])
    );
    console.table(pd);
    console.log(allPlanets.map((k) => k.toString()));

    var allOperators = await read("Portal", "getIdsByType", 4);

    pd = await Promise.all(
      allOperators.map(async (k) => [
        web3.utils.toAscii(await read("Portal", "getNameFromId", k)),
        `id: ${k.toString().substring(0, 8)}`,
        `fee: ${(await read("Portal", "getMaintainerFeeFromId", k))
          .mul(100)
          .div(FEE_DENOMINATOR)
          .toString()}%`,
        `Maintainer: ${await read("Portal", "getMaintainerFromId", k)}`,
        // `pBank: ${web3.utils.hexToAscii(
        //   await read("Portal", "getPBank", k)
        // )}`,
      ])
    );
    console.table(pd);
    console.log(allOperators.map((k) => k.toString()));
  } catch (error) {
    console.log(error);
    console.log("Unsuccesful catching...");
    console.log("try --network");
  }
};

module.exports = func;
