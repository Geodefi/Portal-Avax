const { solidity } = require("ethereum-waffle");
const { BigNumber, ContractFactory, Signer } = require("ethers");

//import { abi as LPToken} from "../build/artifacts/contracts/LPToken.sol/LPToken.json"
//import { SwapFlashLoan } from "../build/typechain/SwapFlashLoan"
//import { GenericERC20 } from "../build/typechain/GenericERC20"

const chai = require("chai");

const { deployments, ethers } = require("hardhat");
const { asyncForEach, MAX_UINT256 } = require("../testUtils");

chai.use(solidity);
const { expect } = chai;

describe("LPToken", async () => {
  let signers;
  let owner;
  let firstToken;
  let lpTokenFactory;

  const setupTest = deployments.createFixture(
    async ({ deployments, ethers }) => {
      await deployments.fixture(); // ensure you start from a fresh deployments

      signers = await ethers.getSigners();
      owner = signers[0];
      lpTokenFactory = await ethers.getContractFactory("LPToken");
      firstToken = await lpTokenFactory.deploy();
      firstToken.initialize("Test Token", "TEST");
    }
  );

  beforeEach(async () => {
    await setupTest();
  });

  it("Reverts when minting 0", async () => {
    // Deploy dummy tokens

    await expect(
      firstToken.mint(await owner.getAddress(), 0)
    ).to.be.revertedWith("LPToken: cannot mint 0");
  });

  it("Reverts when transferring the token to itself", async () => {
    // Transferring LPToken to itself should revert
    await expect(
      firstToken.transfer(firstToken.address, String(100e18))
    ).to.be.revertedWith("LPToken: cannot send to itself");
  });
});
