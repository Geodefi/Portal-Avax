const { solidity } = require("ethereum-waffle");
const { deployments } = require("hardhat");
const { constants } = require("ethers");
const web3 = require("web3");
w3 = new web3(
  "https://eth-mainnet.alchemyapi.io/v2/RWIJcoIxj8EVIfhoDC-Vz5o5t_SmsbZP"
);

const chai = require("chai");

const { ZERO_ADDRESS } = require("../testUtils");

chai.use(solidity);
const { expect } = chai;

const AWEEK = 7 * 24 * 60 * 60;

describe("Portal", async () => {
  let GOVERNANCE;
  let ORACLE;
  let gAVAX;
  let DEFAULT_SWAP_POOL;
  let DEFAULT_INTERFACE;
  let DEFAULT_LP_TOKEN;
  let testPortal;
  let prevContractVersion;
  let anyAddress;
  let planetAddress;
  let operatorAddress;

  const setupTest = deployments.createFixture(async ({ ethers, upgrades }) => {
    const { get } = deployments;
    const signers = await ethers.getSigners();
    GOVERNANCE = signers[0];
    anyAddress = signers[1];
    planetAddress = signers[2];
    operatorAddress = signers[3];

    await deployments.fixture(); // ensure you start from a fresh deployments
    const Portal = await ethers.getContractFactory("Portal", {
      libraries: {
        DataStoreUtils: (await get("DataStoreUtils")).address,
        GeodeUtils: (await get("GeodeUtils")).address,
        StakeUtils: (await get("StakeUtils")).address,
      },
    });
    // https://docs.openzeppelin.com/upgrades-plugins/1.x/hardhat-upgrades
    ORACLE = GOVERNANCE.address; //just for test purposes
    gAVAX = (await get("gAVAX")).address;
    DEFAULT_SWAP_POOL = (await get("Swap")).address;
    DEFAULT_INTERFACE = (await get("ERC20InterfaceUpgradable")).address;
    DEFAULT_LP_TOKEN = (await get("LPToken")).address;

    testPortal = await upgrades.deployProxy(
      Portal,
      [
        GOVERNANCE.address,
        ORACLE,
        gAVAX,
        DEFAULT_SWAP_POOL,
        DEFAULT_INTERFACE,
        DEFAULT_LP_TOKEN,
      ],
      { unsafeAllow: ["external-library-linking"] }
    );
    await testPortal.deployed();
  });

  beforeEach(async () => {
    await setupTest();
  });

  describe("Portal Upgrade", () => {
    const { get } = deployments;
    describe("Permission required before upgrade", async () => {
      it("Upgrade contract fails since it is not allowed to upgrade", async () => {
        let PortalV2Factory = await ethers.getContractFactory("PortalV2", {
          libraries: {
            DataStoreUtils: (await get("DataStoreUtils")).address,
            GeodeUtils: (await get("GeodeUtils")).address,
            StakeUtils: (await get("StakeUtils")).address,
          },
        });
        let testPortalV2 = await PortalV2Factory.deploy();

        await expect(
          testPortal.upgradeTo(testPortalV2.address)
        ).to.be.revertedWith("Portal: is not allowed to upgrade");
      });
    });

    describe("Upgrade proposal allowed", async () => {
      beforeEach("Upgrade contract", async () => {
        prevContractVersion = await testPortal.getVersion();

        let PortalV2Factory = await ethers.getContractFactory("PortalV2", {
          libraries: {
            DataStoreUtils: (await get("DataStoreUtils")).address,
            GeodeUtils: (await get("GeodeUtils")).address,
            StakeUtils: (await get("StakeUtils")).address,
          },
        });
        let testPortalV2 = await PortalV2Factory.deploy();

        _name = web3.utils.asciiToHex("RANDOM");
        _id = await testPortal.getIdFromName("RANDOM");
        await testPortal.newProposal(testPortalV2.address, 2, 100000, _name);
        await testPortal.approveProposal(_id);

        await testPortal.upgradeTo(testPortalV2.address);
        testPortal = await ethers.getContractAt("PortalV2", testPortal.address);
        await testPortal.initializeV2(2);
      });

      it("Check version", async () => {
        let currentContractVersion = await testPortal.getVersion();
        expect(prevContractVersion).not.to.be.eq(currentContractVersion);
        expect(prevContractVersion).to.be.eq(1);
        expect(currentContractVersion).to.be.eq(2);
      });

      it("Check new functions and states are working", async () => {
        expect(await testPortal.getNewParam()).to.be.eq(0);
        await testPortal.setNewParam(69);
        expect(await testPortal.getNewParam()).to.be.eq(69);
        expect(await testPortal.getNewConstParam()).to.be.eq(42);
      });

      it("Check modifiers are working", async () => {
        expect(await testPortal.connect(anyAddress).getNewParam()).to.be.eq(0);
        await testPortal.connect(anyAddress).setNewParam(69);
        expect(await testPortal.connect(anyAddress).getNewParam()).to.be.eq(69);
        expect(
          await testPortal.connect(anyAddress).getNewConstParam()
        ).to.be.eq(42);

        await expect(
          testPortal.connect(anyAddress).getNewParamOnlyGovernance()
        ).to.be.revertedWith("Portal: sender not GOVERNANCE");
        await expect(
          testPortal.connect(anyAddress).setNewParamOnlyGovernance(69)
        ).to.be.revertedWith("Portal: sender not GOVERNANCE");

        expect(await testPortal.getNewParamOnlyGovernance()).to.be.eq(69);
        await testPortal.setNewParamOnlyGovernance(420);
        expect(await testPortal.getNewParamOnlyGovernance()).to.be.eq(420);
      });
    });
  });

  describe("Portal tests", () => {
    describe("onlyGovernance", () => {
      it("newProposal rejects when not governance", async () => {
        await expect(
          testPortal.connect(anyAddress).newProposal(
            planetAddress.address,
            5, // planet type
            AWEEK - 1, // 1 weeks - 1 seconds
            web3.utils.asciiToHex("myLovelyPlanet")
          )
        ).to.be.revertedWith("Portal: sender not GOVERNANCE");
      });

      it("newProposal works if governance", async () => {
        await testPortal.newProposal(
          planetAddress.address,
          5, // planet type
          AWEEK - 1, // 1 weeks - 1 seconds
          web3.utils.asciiToHex("myLovelyPlanet")
        );
      });

      it("pause rejects when not governance", async () => {
        await expect(testPortal.connect(anyAddress).pause()).to.be.revertedWith(
          "Portal: sender not GOVERNANCE"
        );
      });

      it("pause works if governance", async () => {
        await testPortal.pause();
      });

      it("unpause rejects when not governance", async () => {
        await testPortal.pause();
        await expect(
          testPortal.connect(anyAddress).unpause()
        ).to.be.revertedWith("Portal: sender not GOVERNANCE");
      });

      it("unpause works if governance", async () => {
        await testPortal.pause();
        await testPortal.unpause();
      });

      it("setOperationFee rejects when not governance", async () => {
        await expect(
          testPortal.connect(anyAddress).setOperationFee(0)
        ).to.be.revertedWith("Portal: sender not GOVERNANCE");
      });

      it("setOperationFee works if governance", async () => {
        await testPortal.setOperationFee(0);
      });

      it("setMaxMaintainerFee rejects when not governance", async () => {
        await expect(
          testPortal.connect(anyAddress).setMaxMaintainerFee(50000)
        ).to.be.revertedWith("Portal: sender not GOVERNANCE");
      });

      it("setMaxMaintainerFee works if governance", async () => {
        await testPortal.setMaxMaintainerFee(500000);
      });

      it("setDefaultInterface rejects when not governance", async () => {
        const newDefaultInterfaceAddress = w3.eth.accounts.create().address;
        await expect(
          testPortal
            .connect(anyAddress)
            .setDefaultInterface(newDefaultInterfaceAddress)
        ).to.be.revertedWith("Portal: sender not GOVERNANCE");
      });

      it("setDefaultInterface works if governance", async () => {
        const newDefaultInterfaceAddress = w3.eth.accounts.create().address;
        await testPortal.setDefaultInterface(newDefaultInterfaceAddress);
      });
    });

    describe("SetPlanetInterface", () => {
      // should we test gavax setInterface function as an integration test or are we good to go with unit tests?
      let planet_id;

      beforeEach(async () => {
        const { get } = deployments;

        //set gAvax minter as Portal
        gAVAX = await ethers.getContractAt(
          "gAVAX",
          (
            await get("gAVAX")
          ).address
        );
        await gAVAX.updateMinterPauserOracle(testPortal.address);

        // create a planet
        await testPortal.newProposal(
          planetAddress.address,
          5, // planet type
          AWEEK - 1, // 1 weeks - 1 seconds
          web3.utils.asciiToHex("myLovelyPlanet")
        );
        planet_id = await testPortal.getIdFromName("myLovelyPlanet");
        await testPortal.approveProposal(planet_id);
      });

      it("rejected if sender not maintainer", async () => {
        const newInterfaceAddress = w3.eth.accounts.create().address;
        await expect(
          testPortal
            .connect(anyAddress)
            .setPlanetInterface(planet_id, newInterfaceAddress, true)
        ).to.be.revertedWith("Portal: sender not maintainer");
      });

      it("if isSet true, but new interface is not a contract, it reverts", async () => {
        const newInterfaceAddress = w3.eth.accounts.create().address;
        await expect(
          testPortal
            .connect(planetAddress)
            .setPlanetInterface(planet_id, newInterfaceAddress, true)
        ).to.be.revertedWith("gAVAX: _Interface must be a contract");
      });

      it("if isSet true, new interface will be the given interface", async () => {
        const newInterfaceAddress = testPortal.address;
        let prevInterface = await testPortal.planetCurrentInterface(planet_id);

        await testPortal
          .connect(planetAddress)
          .setPlanetInterface(planet_id, newInterfaceAddress, true);
        expect(await testPortal.planetCurrentInterface(planet_id)).to.be.eq(
          newInterfaceAddress
        );
      });

      it("if isSet is false and the given interface is the current interface, interface is set as zero address", async () => {
        let currentInterface = await testPortal.planetCurrentInterface(
          planet_id
        );
        await testPortal
          .connect(planetAddress)
          .setPlanetInterface(planet_id, currentInterface, false);
        expect(await testPortal.planetCurrentInterface(planet_id)).to.be.eq(
          ZERO_ADDRESS
        );
      });
    });

    describe("setPBank", () => {
      let operator_id;
      let planet_id;

      beforeEach(async () => {
        const { get } = deployments;

        //set gAvax minter as Portal
        gAVAX = await ethers.getContractAt(
          "gAVAX",
          (
            await get("gAVAX")
          ).address
        );
        await gAVAX.updateMinterPauserOracle(testPortal.address);

        // create a planet
        await testPortal.newProposal(
          planetAddress.address,
          5, // planet type
          AWEEK - 1, // 1 weeks - 1 seconds
          web3.utils.asciiToHex("myLovelyPlanet")
        );
        planet_id = await testPortal.getIdFromName("myLovelyPlanet");
        await testPortal.approveProposal(planet_id);

        // create an operator
        await testPortal.newProposal(
          operatorAddress.address,
          4, // operator type
          AWEEK - 1, // 1 weeks - 1 seconds
          web3.utils.asciiToHex("myLovelyOperator")
        );
        operator_id = await testPortal.getIdFromName("myLovelyOperator");
        await testPortal.approveProposal(operator_id);
      });

      it("rejected if sender not maintainer", async () => {
        const pBank = ethers.utils.formatBytes32String("RANDOM"); // P-avax1v049pqufjdkykkzv7emld7vmpnpzlekzpq9cst
        await expect(
          testPortal.connect(anyAddress).setPBank(operator_id, planet_id, pBank)
        ).to.be.revertedWith("Portal: sender not maintainer");
      });

      it("succeeds", async () => {
        // const pBank = ethers.utils.formatBytes32String("RANDOM"); // P-avax1v049pqufjdkykkzv7emld7vmpnpzlekzpq9cst
        const pBank = web3.utils.asciiToHex(
          "P-avax1v049pqufjdkykkzv7emld7vmpnpzlekzpq9cst"
        ); // P-avax1v049pqufjdkykkzv7emld7vmpnpzlekzpq9cst
        await testPortal
          .connect(operatorAddress)
          .setPBank(operator_id, planet_id, pBank);
        const gettedPBank = await testPortal
          .connect(operatorAddress)
          .getPBank(operator_id, planet_id);
        expect(web3.utils.hexToAscii(gettedPBank)).to.be.eq(
          "P-avax1v049pqufjdkykkzv7emld7vmpnpzlekzpq9cst"
        ); // P-avax1v049pqufjdkykkzv7emld7vmpnpzlekzpq9cst
      });
    });

    describe("approveProposal", () => {
      it("if proposal is operator, maintainer should be set as controller", async () => {
        // create an operator
        await testPortal.newProposal(
          operatorAddress.address,
          4, // operator type
          AWEEK - 1, // 1 weeks - 1 seconds
          web3.utils.asciiToHex("myLovelyOperator")
        );
        const operator_id = await testPortal.getIdFromName("myLovelyOperator");
        await testPortal.approveProposal(operator_id);
        expect(await testPortal.getMaintainerFromId(operator_id)).to.be.eq(
          operatorAddress.address
        );
      });

      it("if proposal is planet, maintainer should be set as controller, WithdrawalPool should have an address and governance should able to call onlyOwner functions", async () => {
        const { get } = deployments;

        //set gAvax minter as Portal
        const gAVAX = await ethers.getContractAt(
          "gAVAX",
          (
            await get("gAVAX")
          ).address
        );
        await gAVAX.updateMinterPauserOracle(testPortal.address);

        // create a planet
        await testPortal.newProposal(
          planetAddress.address,
          5, // planet type
          AWEEK - 1, // 1 weeks - 1 seconds
          web3.utils.asciiToHex("myLovelyPlanet")
        );
        const planet_id = await testPortal.getIdFromName("myLovelyPlanet");
        await testPortal.approveProposal(planet_id);
        expect(await testPortal.getMaintainerFromId(planet_id)).to.be.eq(
          planetAddress.address
        );
        const withdrawalPoolAddress = await testPortal.planetWithdrawalPool(
          planet_id
        );
        const withdrawalPool = await ethers.getContractAt(
          "Swap",
          withdrawalPoolAddress
        );
        await withdrawalPool.setAdminFee(5);
      });
    });

    describe("planetClaimableSurplus", () => {});

    describe("planetDebt", () => {});
  });
});
