const { task } = require("hardhat/config");
const details = require("./details");
const activatePortal = require("./activatePortal");
const propose = require("./propose");
const approve = require("./approve");
const elect = require("./elect");
const slippageSet = require("./slippageSet");
const rampA = require("./rampA");
const controllerSet = require("./controllerSet");
const maintainerSet = require("./maintainerSet");
const activateOperator = require("./activateOperator");
const deactivateOperator = require("./deactivateOperator");
const pBankSet = require("./pBankSet");
const feeSet = require("./feeSet");
const upgradePortal = require("./upgradePortal");

task("accounts", "Prints the list of accounts", async (taskArgs, hre) => {
  const accounts = await hre.ethers.getSigners();
  for (const account of accounts) {
    console.log(account.address);
  }
});

task("details", "List all details from deployment").setAction(details);
task("activatePortal", "sets Portal as minter for gAVAX").setAction(
  activatePortal
);

task("propose", "Creates a proposal with desired parameters")
  .addParam(
    "type",
    "defines type such as planet , operator , senate , Upgrade, ProxyAdminUpgrade"
  )
  .addParam(
    "controller",
    "refers to the proposed address as the controller of resulting ID"
  )
  .addParam("name", "defines id with keccak")
  .setAction(propose);

task("approve", "Approves a proposal with given id")
  .addOptionalParam("id", "define the given proposal to approve")
  .addOptionalParam("name", "defines id with keccak")
  .setAction(approve);

task("elect", "Approves a Senate proposal")
  .addParam("sid", "define the given senate to approve")
  .addParam("pid", "define id of planet")
  .setAction(elect);

task(
  "slippageSet",
  "changes the slippage for future debt calculations in StakeUtils"
)
  .addParam("s", "new slippage")
  .setAction(slippageSet);

task("rampA", "Change A parameter of Withdrawal Pool of given ID ")
  .addParam("a", "new A")
  .addParam("id", "id of planet")
  .setAction(rampA);

task("controllerSet", " Change CONTROLLER of an ID as CONTROLLER")
  .addParam("id", "id of planet")
  .addParam("c", "new CONTROLLER")
  .setAction(controllerSet);

task("maintainerSet", "Change maintainer of an ID as CONTROLLER")
  .addParam("id", "id of planet")
  .addParam("m", "new maintainer")
  .setAction(maintainerSet);

task("activateOperator", "activate an id for ClaimSurplus and PayDebt")
  .addParam("pid", "id of planet")
  .addParam("oid", "id of operator")
  .setAction(activateOperator);

task("deactivateOperator", "deactivate an operator")
  .addParam("pid", "id of planet")
  .addParam("oid", "id of operator")
  .setAction(deactivateOperator);

task("pBankSet", "Change maintainer of an ID as CONTROLLER")
  .addParam("oid", "id of operator")
  .addParam("pid", "id of planet")
  .addParam("bank", "p chain address to be tracked by telescope")
  .setAction(pBankSet);

task("feeSet", "Change fee of an ID")
  .addParam("id", "id for maintainer")
  .addParam("fee", "fee")
  .setAction(feeSet);

task(
  "upgradePortal",
  "Upgrade the portal with redeploying related libraries and implementation"
).setAction(upgradePortal);
