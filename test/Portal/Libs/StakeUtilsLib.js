const { BigNumber, constants } = require("ethers");

const {
  ZERO_ADDRESS,
  MAX_UINT256,
  getCurrentBlockTimestamp,
  setTimestamp,
} = require("../../testUtils");

const { solidity } = require("ethereum-waffle");
const { deployments, waffle } = require("hardhat");
const web3 = require("web3");
w3 = new web3(
  "https://eth-mainnet.alchemyapi.io/v2/RWIJcoIxj8EVIfhoDC-Vz5o5t_SmsbZP"
);
const chai = require("chai");

chai.use(solidity);
const { expect } = chai;
const randId = 696969696969;
const randId2 = 420420420;
const randId3 = 3131313131;
const wrongId = 69;
const wrappedAvaxId = 1;
const provider = waffle.provider;
const INITIAL_A_VALUE = 60;
const SWAP_FEE = 4e6; // 4bps
const ADMIN_FEE = 5e9; // 0

describe("StakeUtils", async () => {
  var gAVAX;
  var deployer;
  var oracle;
  var representative;
  var operator;
  var user1;
  var user2;
  var DEFAULT_SWAP_POOL;
  var DEFAULT_LP_TOKEN;
  const setupTest = deployments.createFixture(async ({ ethers }) => {
    await deployments.fixture(); // ensure you start from a fresh deployments
    const { get } = deployments;
    signers = await ethers.getSigners();

    deployer = signers[0];
    oracle = signers[1];
    representative = signers[2];
    operator = signers[3];
    user1 = signers[4];
    user2 = signers[5];

    gAVAX = await ethers.getContractAt("gAVAX", (await get("gAVAX")).address);

    DEFAULT_SWAP_POOL = (await get("Swap")).address;
    DEFAULT_LP_TOKEN = (await get("LPToken")).address;

    const TestGeodeUtils = await ethers.getContractFactory("TestStakeUtils", {
      libraries: {
        DataStoreUtils: (await get("DataStoreUtils")).address,
        StakeUtils: (await get("StakeUtils")).address,
      },
    });

    testContract = await TestGeodeUtils.deploy(
      gAVAX.address,
      oracle.address,
      DEFAULT_SWAP_POOL,
      DEFAULT_LP_TOKEN
    );
    await gAVAX.updateMinterPauserOracle(testContract.address);
  });

  beforeEach(async () => {
    await setupTest();
  });

  describe("After Creation TX", () => {
    var stakepool;
    beforeEach(async () => {
      stakepool = await testContract.getStakePoolParams();
    });
    it("correct ORACLE", async () => {
      expect(stakepool.ORACLE).to.eq(oracle.address);
    });
    it("correct gAVAX", async () => {
      expect(stakepool.gAVAX).to.eq(gAVAX.address);
    });
    it("correct FEE_DENOMINATOR", async () => {
      expect(stakepool.FEE_DENOMINATOR).to.eq(1e10);
    });
    it("correct DEFAULT_SWAP_POOL", async () => {
      expect(stakepool.DEFAULT_SWAP_POOL).to.eq(DEFAULT_SWAP_POOL);
    });
    it("correct DEFAULT_LP_TOKEN", async () => {
      expect(stakepool.DEFAULT_LP_TOKEN).to.eq(DEFAULT_LP_TOKEN);
    });
    it("correct DEFAULT_A", async () => {
      expect(stakepool.DEFAULT_A).to.eq(60);
    });
    it("correct DEFAULT_FEE", async () => {
      expect(stakepool.DEFAULT_FEE).to.eq(4e6);
    });
    it("correct DEFAULT_ADMIN_FEE", async () => {
      expect(stakepool.DEFAULT_ADMIN_FEE).to.eq(5e9);
    });
    it("correct PERIOD_PRICE_INCREASE_LIMIT", async () => {
      expect(stakepool.PERIOD_PRICE_INCREASE_LIMIT).to.eq(5e7);
    });
    it("correct MAX_MAINTAINER_FEE", async () => {
      expect(stakepool.MAX_MAINTAINER_FEE).to.eq(1e9);
    });
  });

  describe("distinct Functions", () => {
    describe("mint", () => {
      it("succeeds with random id", async () => {
        var preBalance = await gAVAX.balanceOf(user1.address, randId);
        expect(preBalance).to.eq(0);
        await testContract
          .connect(deployer)
          .mint(gAVAX.address, user1.address, randId, 100);

        var postBalance = await gAVAX.balanceOf(user1.address, randId);
        expect(postBalance).to.eq(100);
      });
      it("can NOT mint id= 0", async () => {
        await expect(
          testContract
            .connect(deployer)
            .mint(gAVAX.address, user1.address, 0, 100)
        ).to.be.revertedWith("StakeUtils: _mint id should be > 0");
      });
      it("can mint id= 1", async () => {
        var preBalance = await gAVAX.balanceOf(user1.address, wrappedAvaxId);
        expect(preBalance).to.eq(0);
        await testContract
          .connect(deployer)
          .mint(gAVAX.address, user1.address, wrappedAvaxId, 100);
        var postBalance = await gAVAX.balanceOf(user1.address, wrappedAvaxId);
        expect(postBalance).to.eq(100);
      });
    });
    describe("setPricePerShare", () => {
      var newPrice = String(1e18);
      var diffPrice = String(2e18);
      it("can NOT set price for id = 0 ", async () => {
        await expect(
          testContract.setPricePerShare(newPrice, 0)
        ).to.be.revertedWith("StakeUtils: id should be > 0");
      });
      it("can set price for id = 1", async () => {
        await testContract.setPricePerShare(newPrice, 1);
      });
      it("can set price for id = rand", async () => {
        await testContract.setPricePerShare(newPrice, randId);
      });
      it("mint amount is not affected with same price", async () => {
        testContract.setPricePerShare(newPrice, 12);
        var preBalance = await gAVAX.balanceOf(user1.address, randId);
        expect(preBalance).to.eq(0);
        await testContract
          .connect(deployer)
          .mint(gAVAX.address, user1.address, randId, 100);
        var postBalance = await gAVAX.balanceOf(user1.address, randId);
        expect(postBalance).to.eq(100);
        await testContract
          .connect(deployer)
          .mint(gAVAX.address, user1.address, randId, 233);
        var lastBalance = await gAVAX.balanceOf(user1.address, randId);
        expect(lastBalance).to.eq(333);
      });
    });
    describe("isOracleActive", () => {
      it("false when inactive", async () => {
        await setTimestamp(24 * 60 * 60 * 100000 - 10);
        await expect(await testContract.isOracleActive(randId)).to.be.eq(false);
      });
      it("true when active", async () => {
        await setTimestamp(24 * 60 * 60 * 100000 + 0 * 60 + 1);
        await expect(await testContract.isOracleActive(randId)).to.be.eq(true);
      });
      it("true when active in 30min", async () => {
        await setTimestamp(24 * 60 * 60 * 100000 + 30 * 60 - 10);
        await expect(await testContract.isOracleActive(randId)).to.be.eq(true);
      });
      it("false when inactive after 30min", async () => {
        await setTimestamp(24 * 60 * 60 * 100000 + 30 * 60 + 1);
        await expect(await testContract.isOracleActive(randId)).to.be.eq(false);
      });
      it("false after oracle update", async () => {
        await setTimestamp(24 * 60 * 60 * 100000 + 0 * 60 + 1);
        await testContract.setOracleTime(randId);
        await expect(await testContract.isOracleActive(randId)).to.be.eq(false);
      });
    });
  });

  describe("Maintainer Logic", () => {
    beforeEach(async () => {
      await testContract.connect(user1).beController(randId);
      await testContract
        .connect(user1)
        .changeIdMaintainer(randId, user1.address);
    });

    describe("get/set MaintainerFee", () => {
      it("Succeeds set", async () => {
        await testContract.connect(user1).setMaintainerFee(randId, 12345);
        expect(await testContract.getMaintainerFee(randId)).to.be.eq(12345);
      });
      it("Reverts if > MAX", async () => {
        await testContract.connect(user1).setMaintainerFee(randId, 10 ** 9);
        await expect(
          testContract.connect(user1).setMaintainerFee(randId, 10 ** 9 + 1)
        ).to.be.revertedWith("StakeUtils: MAX_MAINTAINER_FEE ERROR");
      });
      it("Reverts if not maintainer", async () => {
        await expect(
          testContract.setMaintainerFee(randId, 10 ** 9 + 1)
        ).to.be.revertedWith("StakeUtils: sender not maintainer");
      });
    });

    describe("setMaxMaintainerFee", () => {
      it("succeeds", async () => {
        await testContract.setMaxMaintainerFee(0);
        expect(
          (await testContract.getStakePoolParams()).MAX_MAINTAINER_FEE
        ).to.be.eq(0);

        await testContract.setMaxMaintainerFee(10 ** 10);
        expect(
          (await testContract.getStakePoolParams()).MAX_MAINTAINER_FEE
        ).to.be.eq(10 ** 10);
      });
      it("Reverts if > 100%", async () => {
        await expect(
          testContract.setMaxMaintainerFee(10 ** 10 + 1)
        ).to.be.revertedWith("StakeUtils: fee more than 100%");
      });
    });

    describe("changeMaintainer", () => {
      it("Succeeds", async () => {
        await testContract
          .connect(user1)
          .changeIdMaintainer(randId, user2.address);
        expect(await testContract.getMaintainerFromId(randId)).to.be.eq(
          user2.address
        );
      });
      it("Reverts if not controller ", async () => {
        await expect(
          testContract.changeIdMaintainer(randId, user2.address)
        ).to.be.revertedWith("StakeUtils: not CONTROLLER of given id");
      });
      it("Reverts if ZERO ADDRESS ", async () => {
        await expect(
          testContract.connect(user1).changeIdMaintainer(randId, ZERO_ADDRESS)
        ).to.be.revertedWith("StakeUtils: maintainer can not be zero");
      });
    });
  });

  describe("deployWithdrawalPool", () => {
    var wpoolContract;
    beforeEach(async () => {
      await testContract.deployWithdrawalPool(randId);
      const wpool = await testContract.withdrawalPoolById(randId);
      wpoolContract = await ethers.getContractAt("Swap", wpool);
    });
    describe("check params", () => {
      it("Returns correct A value", async () => {
        expect(await wpoolContract.getA()).to.eq(INITIAL_A_VALUE);
        expect(await wpoolContract.getAPrecise()).to.eq(INITIAL_A_VALUE * 100);
      });

      it("Returns correct fee value", async () => {
        expect((await wpoolContract.swapStorage()).swapFee).to.eq(SWAP_FEE);
      });

      it("Returns correct adminFee value", async () => {
        expect((await wpoolContract.swapStorage()).adminFee).to.eq(ADMIN_FEE);
      });

      describe("LPToken", async () => {
        it("init() fails with already init", async () => {
          const LPcontract = await ethers.getContractAt(
            "LPToken",
            await testContract.LPTokenById(randId)
          );

          await expect(
            LPcontract.initialize("name", "symbol")
          ).to.be.revertedWith(
            "Initializable: contract is already initialized"
          );
        });
      });
    });
    describe("reverts", async () => {
      it("when id = 0", async () => {
        await expect(testContract.deployWithdrawalPool(0)).to.be.revertedWith(
          "StakeUtils: id should be > 0"
        );
      });
      it("when it is already deployed", async () => {
        await expect(
          testContract.deployWithdrawalPool(randId)
        ).to.be.revertedWith("StakeUtils: withdrawalPool already exists");
      });
    });
  });

  describe("Oracle", () => {
    beforeEach(async () => {
      // POOL maintainer
      await testContract.connect(representative).beController(randId);
      await testContract
        .connect(representative)
        .changeIdMaintainer(randId, user1.address);
      await testContract.connect(user1).setMaintainerFee(randId, 1e9); //10%

      // Operator maintainer 1
      await testContract.connect(operator).beController(randId2);
      await testContract
        .connect(operator)
        .changeIdMaintainer(randId2, operator.address);
      await testContract.connect(operator).setMaintainerFee(randId2, 1e8); //1%

      // Operator maintainer 2
      await testContract.connect(user1).beController(randId3);
      await testContract
        .connect(user1)
        .changeIdMaintainer(randId3, user1.address);
      await testContract.connect(user1).setMaintainerFee(randId3, 5e8); //5%
    });

    describe("distributeFees", () => {
      it("reverts when arrays doesnt match", async () => {
        await expect(
          testContract.distributeFees(
            randId,
            [randId2, randId3],
            [100, 1000, 10000]
          )
        ).to.be.revertedWith("StakeUtils: Array lengths doesn't match");
      });

      describe("succesfully changes accumulatedFees", async () => {
        it("for maintainer as also operator", async () => {
          await testContract.distributeFees(randId, [randId], [100000]);
          expect(await testContract.accumulatedFee(randId, randId)).to.be.eq(
            100000 / 10
            //10%
          );
          expect(await testContract.accumulatedFee(randId, randId2)).to.be.eq(
            0
          );
          expect(await testContract.accumulatedFee(randId, randId3)).to.be.eq(
            0
          );
        });

        it("for multiple operators WITH pool maintainer ", async () => {
          await testContract.connect(user1).activateOperator(randId, randId);
          await testContract.connect(user1).activateOperator(randId, randId2);
          await testContract.distributeFees(
            randId,
            [randId, randId2],
            [100, 1000]
          );
          expect(await testContract.accumulatedFee(randId, randId)).to.be.eq(
            1100 / 10
            //10% of total
          );
          expect(await testContract.accumulatedFee(randId, randId2)).to.be.eq(
            1000 / 100
            //1% of their share of profit
          );
          expect(await testContract.accumulatedFee(randId, randId3)).to.be.eq(
            0
          );
        });

        it("for multiple operators other than pool maintainer ", async () => {
          await testContract.connect(user1).activateOperator(randId, randId3);
          await testContract.connect(user1).activateOperator(randId, randId2);
          await testContract.distributeFees(
            randId,
            [randId2, randId3],
            [100, 1000]
          );
          expect(await testContract.accumulatedFee(randId, randId)).to.be.eq(
            1100 / 10
            //10% of total
          );
          expect(await testContract.accumulatedFee(randId, randId2)).to.be.eq(
            100 / 100
            //1% of their share of profit
          );
          expect(await testContract.accumulatedFee(randId, randId3)).to.be.eq(
            (1000 / 100) * 5
            //5% of their share of profit
          );
        });
      });
    });
    describe("ReportOracle ", () => {
      beforeEach(async () => {});
      it("reverts when oracle not caller", async () => {
        await expect(
          testContract.reportOracle(randId, [randId2, randId3], [1000, 10000])
        ).to.be.revertedWith("StakeUtils: msg.sender NOT oracle");
      });
      it("reverts when NOT isOracleActive", async () => {
        await expect(
          testContract
            .connect(oracle)
            .reportOracle(randId, [randId2, randId3], [1000, 10000])
        ).to.be.revertedWith("StakeUtils: Oracle is NOT active");
      });
      it("reverts when no withdrawal pool found aka no price found", async () => {
        await testContract.connect(user1).activateOperator(randId, randId2);
        await setTimestamp(24 * 60 * 60 * 100000 + 0 * 60 + 1);
        await testContract
          .connect(deployer)
          .mint(gAVAX.address, user2.address, randId, String(1e18));

        await expect(
          testContract.connect(oracle).reportOracle(randId, [randId2], [1000])
        ).to.be.revertedWith("StakeUtils: price did NOT met");
      });
      it("reverts when price increased more than 0.5%", async () => {
        await testContract.connect(user1).activateOperator(randId, randId2);
        await setTimestamp(24 * 60 * 60 * 100000 + 0 * 60 + 1);
        await testContract.deployWithdrawalPool(randId);
        await testContract
          .connect(deployer)
          .mint(gAVAX.address, user2.address, randId, String(1000));

        // total amount will change as 1% after the update

        await expect(
          testContract.connect(oracle).reportOracle(randId, [randId2], [7])
        ).to.be.revertedWith("StakeUtils: price did NOT met");
      });
      it("reverts when operator is not activated", async () => {
        await testContract.deployWithdrawalPool(randId);
        await setTimestamp(24 * 60 * 60 * 100000 + 0 * 60 + 1);
        await testContract
          .connect(deployer)
          .mint(gAVAX.address, user2.address, randId, String(20000000));

        await testContract
          .connect(deployer)
          .putSurplus(randId, String(20000000));

        // total amount will change as 0.2% after the update
        await expect(
          testContract
            .connect(oracle)
            .reportOracle(randId, [randId2, randId3], [20000, 20000])
        ).to.be.revertedWith("StakeUtils: _opId activationExpiration has past");
      });
      describe("succeeds", () => {
        beforeEach(async () => {
          await testContract.deployWithdrawalPool(randId);
          await setTimestamp(24 * 60 * 60 * 100000 + 0 * 60 + 1);
          await testContract
            .connect(deployer)
            .mint(gAVAX.address, user2.address, randId, String(20000000));

          await testContract
            .connect(deployer)
            .putSurplus(randId, String(20000000));

          await testContract.connect(user1).activateOperator(randId, randId2);
          await testContract.connect(user1).activateOperator(randId, randId3);

          // total amount will change just shy 0.2% after the update
          await testContract
            .connect(oracle)
            .reportOracle(randId, [randId2, randId3], [20000, 20000]);
        });
        it("pBalance updated accordingly", async () => {
          expect(await testContract.pBalanceById(randId)).to.be.eq(40000);
        });
        it("unclaimedFees updated accordingly", async () => {
          expect(await testContract.unclaimedFeesById(randId)).to.be.eq(
            20000 / 100 + 20000 / 20 + 40000 / 10
          );
        });
        it("surplus did not change", async () => {
          expect(await testContract.surplusById(randId)).to.be.eq(
            String(20000000)
          );
        });
        it("price updated accordingly", async () => {
          expect(await gAVAX.pricePerShare(randId)).to.be.eq(
            // surplus= 20000000, pBalance= 40000, fees=5200, Supply= 20000000
            BigNumber.from(String(20000000))
              .add(40000)
              .sub(5200)
              .mul(String(1e18))
              .div(20000000)
          );
        });
        it("reverts if second update right after", async () => {
          await expect(
            testContract
              .connect(oracle)
              .reportOracle(randId, [randId2, randId3], [1000, 10000])
          ).to.be.revertedWith("StakeUtils: Oracle is NOT active");
        });
      });
    });
  });

  describe("Fees & Surplus", () => {
    describe("claimFee and surplus", () => {
      var representativeBal;
      var claimerBal;
      beforeEach(async () => {
        await testContract.connect(representative).beController(randId);
        await testContract
          .connect(representative)
          .changeIdMaintainer(randId, user1.address);
        await testContract.connect(user1).setMaintainerFee(randId, 1e9); //10%
        // Operator maintainer 1
        await testContract.connect(operator).beController(randId2);
        await testContract
          .connect(operator)
          .changeIdMaintainer(randId2, operator.address);

        await testContract.connect(operator).setMaintainerFee(randId2, 1e8); //1%
        await testContract.connect(user1).activateOperator(randId, randId);
        await testContract.connect(user1).activateOperator(randId, randId2);

        await testContract.deployWithdrawalPool(randId);
        await setTimestamp(24 * 60 * 60 * 90000 + 0 * 60 + 1);
        await testContract
          .connect(deployer)
          .mint(gAVAX.address, user2.address, randId, String(20000000));
        await testContract
          .connect(deployer)
          .putSurplus(randId, String(20000000));

        await testContract
          .connect(oracle)
          .reportOracle(randId, [randId2], [1000]);
      });

      describe("claimFee", () => {
        it("accumulatedFees are correct", async () => {
          expect(await testContract.accumulatedFee(randId, randId)).to.be.eq(
            String(100)
          );
          expect(await testContract.accumulatedFee(randId, randId2)).to.be.eq(
            String(10)
          );
        });
        it("reverts when oracle is active", async () => {
          await setTimestamp(24 * 60 * 60 * 100000 + 0 * 60 + 1);
          await expect(
            testContract.connect(user1).claimFee(randId, randId2)
          ).to.be.revertedWith("StakeUtils: Oracle is active");
        });
        it("reverts when there is no surplus", async () => {
          await testContract.connect(deployer).putSurplus(randId, String(0));
          await setTimestamp(24 * 60 * 60 * 100000 + 0 * 60 - 100);
          await expect(
            testContract.connect(user1).claimFee(randId, randId)
          ).to.be.revertedWith(
            "StakeUtils: fee and surplus should be bigger than zero"
          );
        });
        it("reverts when there is no fee", async () => {
          await setTimestamp(24 * 60 * 60 * 100000 + 0 * 60 - 100);
          await testContract.connect(user1).activateOperator(randId, randId3);
          await expect(
            testContract.connect(user1).claimFee(randId, randId3)
          ).to.be.revertedWith(
            "StakeUtils: fee and surplus should be bigger than zero"
          );
        });
        it("reverts when there is no avax", async () => {
          const currentTimestamp = await getCurrentBlockTimestamp();
          await setTimestamp(currentTimestamp + 24 * 60 * 60 * 15 - 100);
          await expect(
            testContract.connect(user1).claimFee(randId, randId2)
          ).to.be.revertedWith("StakeUtils: Failed to send Avax");
        });

        it("reverts when op is deactivated and 15 days past", async () => {
          await testContract.connect(user1).deactivateOperator(randId, randId2);
          const currentTimestamp = await getCurrentBlockTimestamp();
          await setTimestamp(currentTimestamp + 24 * 60 * 60 * 15 + 100);
          await expect(
            testContract.connect(user1).claimFee(randId, randId2)
          ).to.be.revertedWith(
            "StakeUtils: operatorId activationExpiration has past"
          );
        });

        it("succeeds when op is deactivated and less than 15 days past", async () => {
          await testContract.Receive({ value: String(1e20) });
          await testContract.connect(deployer).putSurplus(randId, String(10));
          await testContract.connect(user1).deactivateOperator(randId, randId2);
          const currentTimestamp = await getCurrentBlockTimestamp();
          await setTimestamp(currentTimestamp + 24 * 60 * 60 * 15 - 100);
          await testContract.connect(user1).claimFee(randId, randId2);
        });

        describe("succeeds with lower surplus", () => {
          beforeEach(async () => {
            await testContract.Receive({ value: String(1e20) });
            await testContract.connect(deployer).putSurplus(randId, String(10));
            const currentTimestamp = await getCurrentBlockTimestamp();
            await setTimestamp(currentTimestamp + 24 * 60 * 60 * 15 - 100);
            representativeBal = await provider.getBalance(user1.address);
            await testContract.claimFee(randId, randId);
          });
          it("accumulatedFee is ZERO", async () => {
            expect(await testContract.accumulatedFee(randId, randId)).to.be.eq(
              90
            );
          });
          it("unclaimedFees is decreased and correct", async () => {
            expect(await testContract.unclaimedFees(randId)).to.be.eq(
              String(100)
            );
          });
          it("accumulatedFee for other id unchanged", async () => {
            expect(await testContract.accumulatedFee(randId, randId2)).to.be.eq(
              String(10)
            );
          });
          it("claimer's maintainer gets AVAX", async () => {
            const newBal = await provider.getBalance(user1.address);
            expect(newBal).to.be.eq(representativeBal.add(String(10)));
          });
        });
        describe("succeeds with higher surplus", () => {
          beforeEach(async () => {
            await testContract.Receive({ value: String(1e20) });
            await testContract
              .connect(deployer)
              .putSurplus(randId, String(1e18));
            const currentTimestamp = await getCurrentBlockTimestamp();
            await setTimestamp(currentTimestamp + 24 * 60 * 60 * 15 - 100);
            representativeBal = await provider.getBalance(user1.address);
            await testContract.claimFee(randId, randId);
          });
          it("accumulatedFee is ZERO", async () => {
            expect(await testContract.accumulatedFee(randId, randId)).to.be.eq(
              0
            );
          });
          it("unclaimedFees is decreased and correct", async () => {
            expect(await testContract.unclaimedFees(randId)).to.be.eq(
              String(10)
            );
          });
          it("accumulatedFee for other id unchanged", async () => {
            expect(await testContract.accumulatedFee(randId, randId2)).to.be.eq(
              String(10)
            );
          });
          it("claimer's maintainer gets AVAX", async () => {
            const newBal = await provider.getBalance(user1.address);
            expect(newBal).to.be.eq(representativeBal.add(String(100)));
          });
        });
      });
      describe("claimSurplus", () => {
        it("reverts when oracle is active", async () => {
          await setTimestamp(24 * 60 * 60 * 100000 + 0 * 60 + 1);
          await expect(
            testContract.connect(operator).claimSurplus(randId, randId2)
          ).to.be.revertedWith("StakeUtils: Oracle is active");
        });
        it("reverts when surplus is Insufficient", async () => {
          await testContract.connect(deployer).putSurplus(randId, String(100));

          await expect(
            testContract.connect(operator).claimSurplus(randId, randId2)
          ).to.be.revertedWith("StakeUtils: pool fees exceed surplus");
        });
        it("reverts when not maintainer is calling", async () => {
          await expect(
            testContract.connect(representative).claimSurplus(randId, randId2)
          ).to.be.revertedWith("StakeUtils: sender not maintainer");
        });
        describe("succeeds when surplus is sufficient ", () => {
          var gasUsed;
          beforeEach(async () => {
            await testContract.Receive({ value: String(1e20) });
            claimerBal = await provider.getBalance(operator.address);
            const tx = await testContract
              .connect(operator)
              .claimSurplus(randId, randId2);
            const receipt = await tx.wait();
            gasUsed = receipt.cumulativeGasUsed.mul(receipt.effectiveGasPrice);
          });
          it("surplus = unclaimedFees", async () => {
            expect(await testContract.unclaimedFees(randId)).to.be.eq(
              await testContract.surplusById(randId)
            );
          });
          it("claimer's maintainer gets AVAX", async () => {
            expect(await provider.getBalance(operator.address)).to.be.eq(
              BigNumber.from(claimerBal)
                .sub(gasUsed)
                .add(String(20000000))
                .sub(110) // 110 = fees
            );
          });
          it("reverts on second try", async () => {
            await expect(
              testContract.connect(operator).claimSurplus(randId, randId2)
            ).to.be.revertedWith("pool fees exceed surplus");
          });
        });
      });
    });
  });

  describe("Staking Operations ", () => {
    var wpoolContract;
    var preContBal;
    var preContGavaxBal;
    var preContWavaxBal;

    var preUserBal;
    var preUserGavaxBal;
    var preUserWavaxBal;

    var preSurplus;
    var preTotSup;
    var preWTotSup;
    var debt;
    var preSwapBals;
    beforeEach(async () => {
      await testContract.deployWithdrawalPool(randId);
      const wpool = await testContract.withdrawalPoolById(randId);
      wpoolContract = await ethers.getContractAt("Swap", wpool);

      await testContract.setPricePerShare(String(1e18), randId);

      await testContract
        .connect(deployer)
        .mint(gAVAX.address, deployer.address, randId, String(1e20));

      await gAVAX.connect(deployer).setApprovalForAll(wpool, true);

      // initially there is no debt
      await wpoolContract
        .connect(deployer)
        .addLiquidity([String(1e20), String(1e20)], 0, MAX_UINT256, {
          value: String(1e20),
        });
      debt = await wpoolContract.getDebt();
      expect(debt).to.be.eq(0);
      preUserBal = await provider.getBalance(user1.address);
      preUserGavaxBal = await gAVAX.balanceOf(user1.address, randId);

      preContBal = await provider.getBalance(testContract.address);
      preContGavaxBal = await gAVAX.balanceOf(testContract.address, randId);

      preSurplus = BigNumber.from(await testContract.surplusById(randId));
      preTotSup = await gAVAX.totalSupply(randId);

      preSwapBals = [
        await wpoolContract.getTokenBalance(0),
        await wpoolContract.getTokenBalance(1),
      ];
    });

    describe("Stake ", () => {
      beforeEach(async () => {
        await testContract.beController(randId);
        await testContract.changeIdMaintainer(randId, user1.address);
      });

      it("reverts when wrongId is given", async () => {
        await expect(
          testContract.connect(user1).stake(wrongId, 0, MAX_UINT256, {
            value: String(1e18),
          })
        ).to.be.reverted;
      });
      it("reverts when pool is paused", async () => {
        await testContract.connect(user1).pausePool(randId);
        await expect(
          testContract.stake(randId, 0, MAX_UINT256, {
            value: String(2e18),
          })
        ).to.be.revertedWith("StakeUtils: minting is paused");
      });
      describe("succeeds", () => {
        var gasUsed;
        describe("when NO buyback (no pause, no debt)", () => {
          beforeEach(async () => {
            const tx = await testContract
              .connect(user1)
              .stake(randId, 0, MAX_UINT256, {
                value: String(1e18),
              });
            const receipt = await tx.wait();
            gasUsed = receipt.cumulativeGasUsed.mul(receipt.effectiveGasPrice);
          });
          it("user lost avax more than stake (+gas) ", async () => {
            const newBal = await provider.getBalance(user1.address);
            expect(newBal.add(gasUsed)).to.be.eq(
              BigNumber.from(String(preUserBal)).sub(String(1e18))
            );
          });
          it("user gained gavax (mintedAmount)", async () => {
            var price = await testContract.oraclePrice(randId);
            expect(price).to.be.eq(String(1e18));
            var mintedAmount = BigNumber.from(String(1e18))
              .div(price)
              .mul(String(1e18));
            const newBal = await gAVAX.balanceOf(user1.address, randId);
            expect(newBal).to.be.eq(preUserGavaxBal.add(mintedAmount));
          });
          it("contract gained avax = minted gAVAX", async () => {
            const newBal = await provider.getBalance(testContract.address);
            expect(newBal).to.be.eq(String(preContBal.add(String(1e18))));
          });
          it("contract gAvax bal did not change", async () => {
            const newBal = await gAVAX.balanceOf(testContract.address, randId);
            expect(newBal).to.be.eq(preContGavaxBal);
          });
          it("id surplus increased", async () => {
            const newSur = await testContract.surplusById(randId);
            expect(newSur.toString()).to.be.eq(
              String(preSurplus.add(String(1e18)))
            );
          });
          it("gAVAX minted ", async () => {
            // minted amount from ORACLE PRICE
            var price = await testContract.oraclePrice(randId);
            expect(price).to.be.eq(String(1e18));
            var mintedAmount = BigNumber.from(String(1e18))
              .div(price)
              .mul(String(1e18));
            const TotSup = await gAVAX.totalSupply(randId);
            expect(TotSup.toString()).to.be.eq(
              String(preTotSup.add(mintedAmount))
            );
          });
          it("swapContract gAVAX balances NOT changed", async () => {
            const swapBals = [
              await wpoolContract.getTokenBalance(0),
              await wpoolContract.getTokenBalance(1),
            ];
            expect(swapBals[0]).to.be.eq(preSwapBals[0]); //wrappedAvaxId
            expect(swapBals[1]).to.be.eq(preSwapBals[1]); //gAvax
          });
        });
        describe("when paused pool is unpaused and not balanced", async () => {
          var gasUsed;
          var newPreUserBal;
          beforeEach(async () => {
            await testContract.connect(user1).pausePool(randId);
            await testContract.connect(user1).unpausePool(randId);
            newPreUserBal = await provider.getBalance(user1.address);
            await testContract.connect(deployer).stake(randId, 0, MAX_UINT256, {
              value: String(1e20),
            });
            await wpoolContract
              .connect(deployer)
              .addLiquidity([String(0), String(1e20)], 0, MAX_UINT256);
            debt = await wpoolContract.getDebt();
            preSwapBals = [
              await wpoolContract.getTokenBalance(0),
              await wpoolContract.getTokenBalance(1),
            ];
            const tx = await testContract
              .connect(user1)
              .stake(randId, 0, MAX_UINT256, {
                value: String(5e20),
              });
            const receipt = await tx.wait();
            gasUsed = receipt.cumulativeGasUsed.mul(receipt.effectiveGasPrice);
          });
          it("user lost avax more than stake (+gas) ", async () => {
            const newBal = await provider.getBalance(user1.address);
            expect(newBal).to.be.eq(
              BigNumber.from(String(newPreUserBal))
                .sub(String(5e20))
                .sub(gasUsed)
            );
          });
          it("user gained gavax more than minted amount (+ wrapped) ", async () => {
            var price = await testContract.oraclePrice(randId);
            expect(price).to.be.eq(String(1e18));
            var mintedAmount = BigNumber.from(String(1e18))
              .div(price)
              .mul(String(1e18));
            const newBal = await gAVAX.balanceOf(user1.address, randId);
            expect(newBal).to.be.gt(preUserGavaxBal.add(mintedAmount));
          });
          it("user doesn't hold wrappedAvaxId", async () => {
            const newBal = await gAVAX.balanceOf(user1.address, wrappedAvaxId);
            expect(newBal).to.be.eq(0);
          });
          it("contract gained avax = minted ", async () => {
            const newBal = await provider.getBalance(testContract.address);
            expect(newBal).to.be.eq(
              String(preContBal.add(BigNumber.from("550143212807943082239")))
            );
          });
          it("contract gAvax bal did not change", async () => {
            const newBal = await gAVAX.balanceOf(testContract.address, randId);
            expect(newBal).to.be.eq(preContGavaxBal);
          });
          it("id surplus increased", async () => {
            const newSur = await testContract.surplusById(randId);
            expect(newSur).to.be.eq(BigNumber.from("550143212807943082239"));
          });
          it("swapContract gAVAX and Avax balance changed accordingly", async () => {
            const swapBals = [
              await wpoolContract.getTokenBalance(0),
              await wpoolContract.getTokenBalance(1),
            ];
            expect(swapBals[0]).to.be.eq(
              BigNumber.from(String(preSwapBals[0])).add(debt)
            );
            expect(swapBals[1]).to.be.lt(preSwapBals[1]); //gAvax
          });
        });
      });
    });
  });
});
