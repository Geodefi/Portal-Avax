// SPDX-License-Identifier: MIT
pragma solidity =0.8.7;
import "../../utils/DataStoreLib.sol";
import "../../utils/StakeUtilsLib.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";

contract TestStakeUtils is ERC1155Holder {
  using DataStoreUtils for DataStoreUtils.DataStore;
  using StakeUtils for StakeUtils.StakePool;
  DataStoreUtils.DataStore private DATASTORE;
  StakeUtils.StakePool private STAKEPOOL;

  constructor(
    address _gAVAX,
    address _ORACLE,
    address _DEFAULT_SWAP_POOL,
    address _DEFAULT_LP_TOKEN
  ) {
    STAKEPOOL.ORACLE = _ORACLE;
    STAKEPOOL.gAVAX = _gAVAX;
    STAKEPOOL.FEE_DENOMINATOR = 10**10;
    STAKEPOOL.DEFAULT_SWAP_POOL = _DEFAULT_SWAP_POOL;
    STAKEPOOL.DEFAULT_LP_TOKEN = _DEFAULT_LP_TOKEN;
    STAKEPOOL.DEFAULT_A = 60;
    STAKEPOOL.DEFAULT_FEE = 4e6;
    STAKEPOOL.DEFAULT_ADMIN_FEE = 5e9;
    STAKEPOOL.PERIOD_PRICE_INCREASE_LIMIT =
      (5 * STAKEPOOL.FEE_DENOMINATOR) /
      1e3;
    STAKEPOOL.MAX_MAINTAINER_FEE = (10 * STAKEPOOL.FEE_DENOMINATOR) / 1e2; //10%
  }

  function getStakePoolParams()
    external
    view
    virtual
    returns (StakeUtils.StakePool memory)
  {
    return STAKEPOOL;
  }

  function getgAVAX() public view virtual returns (IgAVAX) {
    return STAKEPOOL.getgAVAX();
  }

  function setPricePerShare(uint256 pricePerShare_, uint256 _id)
    public
    virtual
  {
    STAKEPOOL._setPricePerShare(pricePerShare_, _id);
  }

  function mint(
    address _gAVAX,
    address _to,
    uint256 _id,
    uint256 _amount
  ) external {
    StakeUtils._mint(_gAVAX, _to, _id, _amount);
  }

  function findDEBT(uint256 id) external view returns (uint256) {
    return StakeUtils.withdrawalPoolById(DATASTORE, id).getDebt();
  }

  function buyback(
    address to,
    uint256 planetId,
    uint256 minToBuy,
    uint256 deadline
  ) external payable returns (uint256) {
    return
      STAKEPOOL._buyback(
        DATASTORE,
        to,
        planetId,
        msg.value,
        minToBuy,
        deadline
      );
  }

  /**
  * Maintainer

  */
  function getMaintainerFromId(uint256 _id)
    external
    view
    virtual
    returns (address)
  {
    return DATASTORE.readAddressForId(_id, "maintainer");
  }

  function changeIdMaintainer(uint256 _id, address _newMaintainer)
    external
    virtual
  {
    StakeUtils.changeMaintainer(DATASTORE, _id, _newMaintainer);
  }

  function setMaintainerFee(uint256 _id, uint256 _newFee) external virtual {
    STAKEPOOL.setMaintainerFee(DATASTORE, _id, _newFee);
  }

  function setMaxMaintainerFee(uint256 _newMaxFee) external virtual {
    STAKEPOOL.setMaxMaintainerFee(_newMaxFee);
  }

  function getMaintainerFee(uint256 _id)
    external
    view
    virtual
    returns (uint256)
  {
    return STAKEPOOL.getMaintainerFee(DATASTORE, _id);
  }

  // ORACLE FUNCTIONS

  function isOracleActive(uint256 _id) external view returns (bool) {
    return StakeUtils._isOracleActive(DATASTORE, _id);
  }

  function setOracleTime(uint256 _id) external {
    DATASTORE.writeUintForId(_id, "oracleUpdateTimeStamp", block.timestamp);
  }

  function beController(uint256 _id) external {
    DATASTORE.writeAddressForId(_id, "CONTROLLER", msg.sender);
  }

  function oraclePrice(uint256 _id) external view returns (uint256) {
    return STAKEPOOL.oraclePrice(_id);
  }

  function distributeFees(
    uint256 _planetId,
    uint256[] calldata _opIds,
    uint256[] calldata _pBalanceIncreases
  ) external {
    STAKEPOOL._distributeFees(DATASTORE, _planetId, _opIds, _pBalanceIncreases);
  }

  function reportOracle(
    uint256 _planetId,
    uint256[] calldata _opIds,
    uint256[] calldata _pBalanceIncreases
  ) external returns (uint256 price) {
    price = STAKEPOOL.reportOracle(
      DATASTORE,
      block.timestamp,
      _planetId,
      _opIds,
      _pBalanceIncreases
    );
  }

  // DEBT AND SURPLUS RELATED
  function withdrawalPoolById(uint256 _id)
    external
    view
    virtual
    returns (address)
  {
    return address(StakeUtils.withdrawalPoolById(DATASTORE, _id));
  }

  function LPTokenById(uint256 _id) external view virtual returns (address) {
    return address(StakeUtils.LPTokenById(DATASTORE, _id));
  }

  function payDebt(uint256 _planetId, uint256 claimerId) external payable {
    STAKEPOOL.payDebt(DATASTORE, _planetId, claimerId);
  }

  function surplusById(uint256 _planetId) external view returns (uint256) {
    return DATASTORE.readUintForId(_planetId, "surplus");
  }

  function putSurplus(uint256 _planetId, uint256 newsurplus) external {
    DATASTORE.writeUintForId(_planetId, "surplus", newsurplus);
  }

  function pBalanceById(uint256 _planetId) external view returns (uint256) {
    return DATASTORE.readUintForId(_planetId, "pBalance");
  }

  function unclaimedFeesById(uint256 _planetId)
    external
    view
    returns (uint256)
  {
    return DATASTORE.readUintForId(_planetId, "unclaimedFees");
  }

  function claimSurplus(uint256 _planetId, uint256 claimerId)
    external
    returns (bool)
  {
    return StakeUtils.claimSurplus(DATASTORE, _planetId, claimerId);
  }

  function accumulatedFee(uint256 planetId, uint256 claimerId)
    external
    view
    returns (uint256)
  {
    (uint256 fee, ) = StakeUtils.accumulatedFee(DATASTORE, planetId, claimerId);
    return fee;
  }

  function unclaimedFees(uint256 _poolId) external view returns (uint256) {
    return DATASTORE.readUintForId(_poolId, "unclaimedFees");
  }

  function setMaintainer(uint256 _id, address _maintainer) external {
    DATASTORE.writeAddressForId(_id, "maintainer", _maintainer);
  }

  function claimFee(uint256 planetId, uint256 claimerId) external virtual {
    StakeUtils.claimFee(DATASTORE, planetId, claimerId);
  }

  /**  FUNCTIONS ABOUT SWAP & ROUTING */

  function deployWithdrawalPool(uint256 id)
    external
    returns (address WithdrawalPool)
  {
    return STAKEPOOL.deployWithdrawalPool(DATASTORE, id);
  }

  function activateOperator(uint256 _id, uint256 _activeId)
    external
    virtual
    returns (bool)
  {
    return StakeUtils.activateOperator(DATASTORE, _id, _activeId);
  }

  function deactivateOperator(uint256 _id, uint256 _deactivedId)
    external
    virtual
    returns (bool)
  {
    return StakeUtils.deactivateOperator(DATASTORE, _id, _deactivedId);
  }

  function pausePool(uint256 id) external {
    StakeUtils.pauseStakingForPool(DATASTORE, id);
  }

  function unpausePool(uint256 id) external {
    StakeUtils.unpauseStakingForPool(DATASTORE, id);
  }

  function stake(
    uint256 planetId,
    uint256 minGavax,
    uint256 deadline
  ) external payable returns (uint256 totalgAvax) {
    return STAKEPOOL.stake(DATASTORE, planetId, minGavax, deadline);
  }

  function Receive() external payable {}
}
