// SPDX-License-Identifier: MIT

//   ██████╗ ███████╗ ██████╗ ██████╗ ███████╗    ██████╗  ██████╗ ██████╗ ████████╗ █████╗ ██╗
//  ██╔════╝ ██╔════╝██╔═══██╗██╔══██╗██╔════╝    ██╔══██╗██╔═══██╗██╔══██╗╚══██╔══╝██╔══██╗██║
//  ██║  ███╗█████╗  ██║   ██║██║  ██║█████╗      ██████╔╝██║   ██║██████╔╝   ██║   ███████║██║
//  ██║   ██║██╔══╝  ██║   ██║██║  ██║██╔══╝      ██╔═══╝ ██║   ██║██╔══██╗   ██║   ██╔══██║██║
//  ╚██████╔╝███████╗╚██████╔╝██████╔╝███████╗    ██║     ╚██████╔╝██║  ██║   ██║   ██║  ██║███████╗
//   ╚═════╝ ╚══════╝ ╚═════╝ ╚═════╝ ╚══════╝    ╚═╝      ╚═════╝ ╚═╝  ╚═╝   ╚═╝   ╚═╝  ╚═╝╚══════╝
//

pragma solidity =0.8.7;
import "@openzeppelin/contracts-upgradeable/token/ERC1155/utils/ERC1155HolderUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./utils/DataStoreLib.sol";
import "./utils/GeodeUtilsLib.sol";
import "./utils/StakeUtilsLib.sol";
import "../interfaces/IPortal.sol";
import "../interfaces/IERC20InterfaceUpgradable.sol";

/**
 * @title Geode Finance Avalanche Portal: Avax Liquid Staking
 *
 * Geode Portal is a first of its kind Decentralized Minter that builds
 * a trustless staking Ecosystem for any service provider.
 *
 * @dev refer to DataStoreUtils before reviewing
 * @dev refer to GeodeUtils > Includes the logic for management of Geode Portal with Senate.
 * @dev refer to StakeUtils > Includes the logic for staking functionality with Withdrawal Pools
 * @notice TYPE: seperates the proposals and related functionality between different ID types.
 * * RESERVED TYPES on Portalv1:
 * * * TYPE 4: Operator
 * * * TYPE 5: Planet
 */

contract Portal is
  IPortal,
  ReentrancyGuardUpgradeable,
  PausableUpgradeable,
  ERC1155HolderUpgradeable,
  UUPSUpgradeable
{
  /**
   * @dev following events are added to help fellow devs with better ABIs
   * @dev contract size is not affected
   */
  // GeodeUtils Events
  event OperationFeeUpdated(uint256 newFee);
  event MaxOperationFeeUpdated(uint256 newMaxFee);
  event ControllerChanged(uint256 id, address newCONTROLLER);
  event Proposed(
    uint256 id,
    address _CONTROLLER,
    uint256 _type,
    uint256 _duration
  );
  event ProposalApproved(uint256 id);
  event NewElectorType(uint256 _type);
  event Vote(uint256 proposalId, uint256 electorId);
  event NewSenate(address senate, uint256 senate_expire_timestamp);

  // StakeUtils Events
  event MaintainerFeeUpdated(uint256 id, uint256 fee);
  event MaxMaintainerFeeUpdated(uint256 newMaxFee);
  event PriceChanged(uint256 id, uint256 pricePerShare);
  event OracleUpdate(
    uint256 id,
    uint256 price,
    uint256 newPBalance,
    uint256 distributedFeeTotal,
    uint256 updateTimeStamp
  );
  event OperatorActivated(uint256 id, uint256 activeOperator);
  event OperatorDeactivated(uint256 id, uint256 deactiveOperator);
  event debtPaid(uint256 id, uint256 operatorId, uint256 paidDebt);
  event SurplusClaimed(uint256 id, uint256 newSurplus);
  event FeeClaimed(uint256 id, uint256 claimerId, uint256 newSurplus);
  event PausedPool(uint256 id);
  event UnpausedPool(uint256 id);

  // Portal Events
  event ContractVersionSet(uint256 version);
  event DefaultInterfaceSet(address DefaultInterface);
  event pBankSet(uint256 operatorId, uint256 planetId, bytes pBank);

  using DataStoreUtils for DataStoreUtils.DataStore;
  using GeodeUtils for GeodeUtils.Universe;
  using StakeUtils for StakeUtils.StakePool;

  DataStoreUtils.DataStore private DATASTORE;
  GeodeUtils.Universe private GEODE;
  StakeUtils.StakePool private STAKEPOOL;

  /// @notice Default erc1155 interface, currently allows every id to be act as ERC20
  address public DEFAULT_INTERFACE;
  uint256 public CONTRACT_VERSION;

  function initialize(
    address _GOVERNANCE,
    address _ORACLE,
    address _gAVAX,
    address _DEFAULT_SWAP_POOL,
    address _DEFAULT_INTERFACE,
    address _DEFAULT_LP_TOKEN
  ) public virtual override initializer {
    __ReentrancyGuard_init();
    __Pausable_init();
    __ERC1155Holder_init();
    __UUPSUpgradeable_init();

    require(_GOVERNANCE != address(0), "Portal: _GOVERNANCE can not be zero");
    require(_ORACLE != address(0), "Portal: _ORACLE can not be zero");
    require(_gAVAX != address(0), "Portal: _gAVAX can not be zero");
    require(
      _DEFAULT_SWAP_POOL != address(0),
      "Portal: _DEFAULT_SWAP_POOL can not be zero"
    );
    require(
      _DEFAULT_INTERFACE != address(0),
      "Portal: _DEFAULT_INTERFACE can not be zero"
    );
    require(
      _DEFAULT_LP_TOKEN != address(0),
      "Portal: _DEFAULT_LP_TOKEN can not be zero"
    );
    /**
     * since it is deployment of v1 contracts senate is currently the governance
     * A vote can be proposed when electorCount > 4
     */
    GEODE.GOVERNANCE = _GOVERNANCE;
    GEODE.SENATE = GEODE.GOVERNANCE;
    GEODE.SENATE_EXPIRE_TIMESTAMP =
      block.timestamp +
      GeodeUtils.MAX_SENATE_PERIOD;
    GEODE.OPERATION_FEE = 0;
    GEODE.MAX_OPERATION_FEE = 0;
    GEODE.FEE_DENOMINATOR = 10**10;
    // allow Planets to vote for Senate
    GEODE.setElectorType(DATASTORE, 5, true);

    DEFAULT_INTERFACE = _DEFAULT_INTERFACE;

    STAKEPOOL.FEE_DENOMINATOR = GEODE.FEE_DENOMINATOR;
    STAKEPOOL.gAVAX = _gAVAX;
    STAKEPOOL.ORACLE = _ORACLE;
    STAKEPOOL.DEFAULT_SWAP_POOL = _DEFAULT_SWAP_POOL;
    STAKEPOOL.DEFAULT_LP_TOKEN = _DEFAULT_LP_TOKEN;
    STAKEPOOL.DEFAULT_A = 60;
    STAKEPOOL.DEFAULT_FEE = 4e6;
    STAKEPOOL.DEFAULT_ADMIN_FEE = 5e9;
    STAKEPOOL.PERIOD_PRICE_INCREASE_LIMIT = (2 * GEODE.FEE_DENOMINATOR) / 1e3; // 0.2%
    STAKEPOOL.MAX_MAINTAINER_FEE = (10 * GEODE.FEE_DENOMINATOR) / 1e2; //10%

    GEODE.approvedUpgrade = address(0);

    CONTRACT_VERSION = 1;
    emit ContractVersionSet(1);
  }

  modifier onlyGovernance() {
    require(msg.sender == GEODE.GOVERNANCE, "Portal: sender not GOVERNANCE");
    _;
  }

  /**
   *                                    ** Contract specific functions **
   **/

  ///@dev required by the OZ UUPS module
  function _authorizeUpgrade(address proposed_implementation)
    internal
    virtual
    override
  {
    require(proposed_implementation != address(0));
    require(
      GEODE.isUpgradeAllowed(proposed_implementation),
      "Portal: is not allowed to upgrade"
    );
  }

  function pause() external virtual override onlyGovernance {
    _pause();
  }

  function unpause() external virtual override onlyGovernance {
    _unpause();
  }

  function getVersion() external view virtual override returns (uint256) {
    return CONTRACT_VERSION;
  }

  function gAVAX() external view virtual override returns (address) {
    return address(STAKEPOOL.getgAVAX());
  }

  /**
   *                                          ** GETTERS **
   */

  /**
   *                                    ** GOVERNANCE GETTERS **
   */

  function getSenate() external view virtual override returns (address) {
    return GEODE.getSenate();
  }

  function getGovernance() external view virtual override returns (address) {
    return GEODE.getGovernance();
  }

  function getOperationFee() external view virtual override returns (uint256) {
    return GEODE.getOperationFee();
  }

  function getMaxOperationFee()
    external
    view
    virtual
    override
    returns (uint256)
  {
    return GEODE.getMaxOperationFee();
  }

  function getSenateExpireTimestamp()
    external
    view
    virtual
    override
    returns (uint256)
  {
    return GEODE.getSenateExpireTimestamp();
  }

  function getFeeDenominator()
    external
    view
    virtual
    override
    returns (uint256)
  {
    return GEODE.FEE_DENOMINATOR;
  }

  function getStakePoolParams()
    external
    view
    virtual
    override
    returns (StakeUtils.StakePool memory)
  {
    return STAKEPOOL;
  }

  /*
   *                                          **ID GETTERS **
   */

  /// @return allIdsByType array of DatastoreUtilsLib
  function getIdsByType(uint256 _type)
    external
    view
    virtual
    override
    returns (uint256[] memory)
  {
    return DATASTORE.allIdsByType[_type];
  }

  /// @notice id is keccak(name)
  function getIdFromName(string calldata _name)
    external
    pure
    virtual
    override
    returns (uint256 _id)
  {
    _id = uint256(keccak256(abi.encodePacked(_name)));
  }

  /// @notice returns bytes(0) for empty ids, mandatory
  function getNameFromId(uint256 _id)
    external
    view
    virtual
    override
    returns (bytes memory)
  {
    return DATASTORE.readBytesForId(_id, "name");
  }

  /// @notice returns address(0) for empty ids, mandatory
  function getCONTROLLERFromId(uint256 _id)
    external
    view
    virtual
    override
    returns (address)
  {
    return DATASTORE.readAddressForId(_id, "CONTROLLER");
  }

  /**
   * @notice returns address(0) if NOT set, NOT mandatory
   * @dev maintainer operates the id: claims the fee, pays the debt, signs the messages for verification etc.
   */
  function getMaintainerFromId(uint256 _id)
    external
    view
    virtual
    override
    returns (address)
  {
    return DATASTORE.readAddressForId(_id, "maintainer");
  }

  /// @notice even if MAX_MAINTAINER_FEE is decreased later, it returns limited maximum
  function getMaintainerFeeFromId(uint256 _id)
    external
    view
    virtual
    override
    returns (uint256)
  {
    return STAKEPOOL.getMaintainerFee(DATASTORE, _id);
  }

  /**
   *                                          ** Planet GETTERS **
   **/

  /// @dev not reliable, only shows the latest gAvaxInterface intended use for frontends etc. refer setPlanetInterface
  function planetCurrentInterface(uint256 _id)
    external
    view
    virtual
    override
    returns (address)
  {
    return DATASTORE.readAddressForId(_id, "currentInterface");
  }

  /// @notice pool that maintains the price of the staking derivative
  function planetWithdrawalPool(uint256 _id)
    external
    view
    virtual
    override
    returns (address)
  {
    return address(StakeUtils.withdrawalPoolById(DATASTORE, _id));
  }

  /// @notice LP token of the Withdrawal pool of given ID
  function planetLPToken(uint256 _id)
    external
    view
    virtual
    override
    returns (address)
  {
    return address(StakeUtils.LPTokenById(DATASTORE, _id));
  }

  /**
   * @notice ActiveOperator can claim the surplus of the given staking pool to create validators,
   * @notice There can be only one active operator for an ID. However old active operators can still
   * continue operating until activationExpiration timestamp and acquire fees.
   **/
  function planetActiveOperator(uint256 _id)
    external
    view
    virtual
    override
    returns (uint256)
  {
    return DATASTORE.readUintForId(_id, "activeOperator");
  }

  /**
   *                                              ** Operator GETTERS **
   **/

  function operatorActivationExpiration(uint256 planetId, uint256 operatorId)
    public
    view
    returns (uint256)
  {
    return
      DATASTORE.readUintForId(
        planetId,
        bytes32(keccak256(abi.encodePacked(operatorId, "activationExpiration")))
      );
  }

  /**
   *                                          ** SETTERS **
   */

  /**
   * @notice only CONTROLLER is allowed to change the CONTROLLER of the pool
   * check is done inside the library.
   * @dev this action can not be overwritten by the old CONTROLLER after set.
   */
  function changeIdCONTROLLER(uint256 _id, address _newCONTROLLER)
    external
    virtual
    override
    whenNotPaused
  {
    GeodeUtils.changeIdCONTROLLER(DATASTORE, _id, _newCONTROLLER);
  }

  /**
   * @notice only CONTROLLER is allowed to change the maintainer of the pool
   * check is done inside the library.
   */
  function changeIdMaintainer(uint256 _id, address _newMaintainer)
    external
    virtual
    override
    whenNotPaused
  {
    StakeUtils.changeMaintainer(DATASTORE, _id, _newMaintainer);
  }

  function setMaintainerFee(uint256 _id, uint256 _newFee)
    external
    virtual
    override
  {
    STAKEPOOL.setMaintainerFee(DATASTORE, _id, _newFee);
  }

  /**
   * ** GOVERNANCE/SENATE SETTERS **
   */

  function setOperationFee(uint256 _newFee)
    external
    virtual
    override
    onlyGovernance
    returns (bool success)
  {
    success = GEODE.setOperationFee(_newFee);
  }

  /// @dev onlySenate CHECKED inside
  function setMaxOperationFee(uint256 _newFee)
    external
    virtual
    override
    returns (bool success)
  {
    success = GEODE.setMaxOperationFee(_newFee);
  }

  function setMaxMaintainerFee(uint256 _newMaxFee)
    external
    virtual
    override
    onlyGovernance
  {
    STAKEPOOL.setMaxMaintainerFee(_newMaxFee);
  }

  function setDefaultInterface(address _newDefault)
    external
    virtual
    override
    whenNotPaused
    onlyGovernance
  {
    require(
      _newDefault != address(0),
      "Portal: DEFAULT_INTERFACE can not be zero"
    );
    DEFAULT_INTERFACE = _newDefault;
    emit DefaultInterfaceSet(_newDefault);
  }

  /**
   * ** Planet SETTERS **
   */

  /**
   * @notice When a pool maintainer wants another operator's maintainer to be able to start claiming surplus and
   * creating validators
   */
  function activateOperator(uint256 _id, uint256 _activeId)
    external
    virtual
    override
    whenNotPaused
    returns (bool)
  {
    return StakeUtils.activateOperator(DATASTORE, _id, _activeId);
  }

  /**
   * @notice deactivates an old operator for the given staking pool
   * @dev when activationExpiration is up, operator will NOT be able generate fees from pool,
   * it is expected for them to return the assets as surplus with payDebt function
   * @dev _deactivateAfter seconds until activation expires,
   */
  function deactivateOperator(uint256 _id, uint256 _deactivedId)
    external
    virtual
    override
    returns (bool)
  {
    return StakeUtils.deactivateOperator(DATASTORE, _id, _deactivedId);
  }

  function _setInterface(
    uint256 _id,
    address _Interface,
    bool isSet
  ) internal {
    STAKEPOOL.getgAVAX().setInterface(_Interface, _id, isSet);
    if (isSet) DATASTORE.writeAddressForId(_id, "currentInterface", _Interface);
    else if (DATASTORE.readAddressForId(_id, "currentInterface") == _Interface)
      DATASTORE.writeAddressForId(_id, "currentInterface", address(0));
  }

  /**
   *  @notice if a planet did not unset an old Interface, before setting a new one;
   *  & if new interface is unset, the old one will not be remembered!!
   *  use gAVAX.isInterface(interface,  id)
   * @param _Interface address of the new gAVAX ERC1155 interface for given ID
   * @param isSet true if new interface is going to be set, false if old interface is being unset
   */
  function setPlanetInterface(
    uint256 _id,
    address _Interface,
    bool isSet
  ) external virtual override whenNotPaused {
    require(
      DATASTORE.readAddressForId(_id, "maintainer") == msg.sender,
      "Portal: sender not maintainer"
    );
    _setInterface(_id, _Interface, isSet);
  }

  /**
   * ** Operator SETTERS/GETTERS**
   */

  /**
   * @notice pBank is the only address on the P subchain that interacts with tokens that is claimed by
   * operator as surplus.
   * @dev this logic makes the operator-planet interactions more reliable and transparent
   * when used by oracle to detect the token flow between different subchains.
   */
  function setPBank(
    uint256 operatorId,
    uint256 planetId,
    bytes memory pBank
  ) external virtual override whenNotPaused {
    require(
      DATASTORE.readAddressForId(operatorId, "maintainer") == msg.sender,
      "Portal: sender not maintainer"
    );

    DATASTORE.writeBytesForId(
      operatorId,
      bytes32(keccak256(abi.encodePacked(planetId, "pBank"))),
      pBank
    );
    emit pBankSet(operatorId, planetId, pBank);
  }

  function getPBank(uint256 operatorId, uint256 planetId)
    external
    view
    virtual
    override
    returns (bytes memory)
  {
    return
      DATASTORE.readBytesForId(
        operatorId,
        bytes32(keccak256(abi.encodePacked(planetId, "pBank")))
      );
  }

  /**
   *                                          ** PROPOSALS **
   */

  function getProposal(uint256 id)
    external
    view
    virtual
    override
    returns (GeodeUtils.Proposal memory)
  {
    return GEODE.getProposal(id);
  }

  /**
   * @notice creates a new proposal as id = keccak(name),
   * @param _CONTROLLER address of the
   * @param _type of the proposal is seperator between different user experiences
   * it can be upgrade proposal, senate election, operator/planet proposal etc.
   * @param _proposalDuration proposal can not approved after expiration but can be override
   * @param _name unique, id = keccak(name)
   * @dev "name already claimed check" is being made here as override can be a wanted feature in the future
   */
  function newProposal(
    address _CONTROLLER,
    uint256 _type,
    uint256 _proposalDuration,
    bytes calldata _name
  ) external virtual override whenNotPaused onlyGovernance {
    require(
      DATASTORE
        .readBytesForId(uint256(keccak256(abi.encodePacked(_name))), "name")
        .length == 0,
      "PORTAL: name already claimed"
    );
    GEODE.newProposal(_CONTROLLER, _type, _proposalDuration, _name);
  }

  /**
   * @dev only Senate is checked in GEODE.approveProposal
   */
  function approveProposal(uint256 _id)
    external
    virtual
    override
    whenNotPaused
  {
    /**
     * RESERVED GeodeUtilsLib
     * TYPE 0: inactive
     * TYPE 1: Senate
     * TYPE 2: Upgrade
     * TYPE 3: **deprecated**
     * RESERVED PORTALv1.0
     * TYPE 4: operator
     * TYPE 5: planet(public Staking pool)
     * RESERVED PORTALv1.3:
     * TYPE 6:  TODO :: private Staking pool (only maintainer)
     **/
    GEODE.approveProposal(DATASTORE, _id);
    if (DATASTORE.readUintForId(_id, "TYPE") == 4) {
      // operator
      DATASTORE.writeAddressForId(
        _id,
        "maintainer",
        DATASTORE.readAddressForId(_id, "CONTROLLER")
      );
    } else if (DATASTORE.readUintForId(_id, "TYPE") == 5) {
      // planet
      DATASTORE.writeAddressForId(
        _id,
        "maintainer",
        DATASTORE.readAddressForId(_id, "CONTROLLER")
      );
      address currentInterface = StakeUtils._clone(DEFAULT_INTERFACE);
      IERC20InterfaceUpgradable(currentInterface).initialize(
        _id,
        string(DATASTORE.readBytesForId(_id, "name")),
        address(STAKEPOOL.getgAVAX())
      );
      _setInterface(_id, currentInterface, true);
      address WithdrawalPool = STAKEPOOL.deployWithdrawalPool(DATASTORE, _id);
      Ownable(WithdrawalPool).transferOwnership(GEODE.GOVERNANCE);
    }
  }

  function approveSenate(uint256 proposalId, uint256 electorId)
    external
    virtual
    override
    whenNotPaused
  {
    GEODE.approveSenate(DATASTORE, proposalId, electorId);
  }

  /**
   *                                          ** ORACLE **
   */

  /**
   * @notice oraclePrice is a reliable source for any contract operation on-chain
   * @dev also the *mint price* as gAVAX.pricePerShare(id)
   * @dev TotalStakedAvax can be estimated by: TotalSupply(id) * planetOraclePrice(id)
   */
  function planetOraclePrice(uint256 _id)
    public
    view
    virtual
    override
    returns (uint256 _pricePershare)
  {
    _pricePershare = STAKEPOOL.oraclePrice(_id);
  }

  /**
   * @notice Oracle is only allowed for a period every day & pool operations are stopped then
   * @dev returns false after oracle update for the given pool.
   */
  function isOracleActive(uint256 _planetId)
    external
    view
    virtual
    override
    returns (bool)
  {
    return StakeUtils._isOracleActive(DATASTORE, _planetId);
  }

  /**
   * @notice only Oracle can report a new price. However price is not purely calculated by it.
   * the balance on P subchain is estimated by it, including the unrealized staking rewards.
   * Oracle has a pessimistic approach to make sure price will not decrease by a lot even in the case of loss of funds.

   * @param _opIds all ids of all operators who still collect fees.
   * @param _pBalanceIncreases the amount of avax that has been gained by the operator as POS rewards, respective to _opIds
   * @dev simply the new price is found by (pBALANCE + surplus - fees) / totalSupply)
   * @return price : new price after sanitychecks, might be useful if onchain oracle in the future
   */
  function reportOracle(
    uint256 _reportedTimeStamp,
    uint256 _planetId,
    uint256[] memory _opIds,
    uint256[] memory _pBalanceIncreases
  )
    external
    virtual
    override
    nonReentrant
    whenNotPaused
    returns (uint256 price)
  {
    price = STAKEPOOL.reportOracle(
      DATASTORE,
      _reportedTimeStamp,
      _planetId,
      _opIds,
      _pBalanceIncreases
    );
  }

  /**
   *                                          ** DEBT & SURPLUS **
   */

  /// @notice total amount of staked Avax that has been waiting to be staked
  function planetSurplus(uint256 planetId)
    external
    view
    virtual
    override
    returns (uint256)
  {
    return DATASTORE.readUintForId(planetId, "surplus");
  }

  /// @notice total amount of staked Avax that can be claimed, as Fees are not claimable to be staked
  function planetClaimableSurplus(uint256 planetId)
    external
    view
    virtual
    override
    returns (uint256)
  {
    uint256 _surplus = DATASTORE.readUintForId(planetId, "surplus");
    uint256 _unclaimedFees = DATASTORE.readUintForId(planetId, "unclaimedFees");
    if (_surplus > _unclaimedFees) {
      return _surplus - _unclaimedFees;
    } else {
      return 0;
    }
  }

  /**
   * @notice amount of fee (as AVAX) that has been distributed in a staking pool, without being claimed
   */
  function unclaimedFees(uint256 planetId)
    external
    view
    virtual
    override
    returns (uint256 fee)
  {
    fee = DATASTORE.readUintForId(planetId, "unclaimedFees");
  }

  /**
   * @notice amount of fee (as AVAX) that has been distributed to the maintainer so far
   * @dev for planet's maintainer's accumulatedFee (planetId,planetId)
   */
  function accumulatedFee(uint256 planetId, uint256 claimerId)
    external
    view
    virtual
    override
    returns (uint256)
  {
    (uint256 fee, ) = StakeUtils.accumulatedFee(DATASTORE, planetId, claimerId);
    return fee;
  }

  /**
   * @notice When a debt is calculated, it also takes the unclaimed Fees into consideration for the Planet
   * since payDebt pays that -if it is more than surplus- first and then covers the withdrawal Pool.
   * @return debtInAvax is the current debt amount that pays for fees and provides a stable price to withdrawalPool
   */
  function planetDebt(uint256 planetId)
    external
    view
    virtual
    override
    returns (uint256 debtInAvax)
  {
    debtInAvax = StakeUtils.withdrawalPoolById(DATASTORE, planetId).getDebt();
    if (
      DATASTORE.readUintForId(planetId, "unclaimedFees") >
      DATASTORE.readUintForId(planetId, "surplus")
    ) {
      uint256 debtInFees = DATASTORE.readUintForId(planetId, "unclaimedFees") -
        DATASTORE.readUintForId(planetId, "surplus");
      debtInAvax += debtInFees;
    }
  }

  /**
   * @notice Debt of the planet is found by approaching to it's price within WithdrawalPool
   * @return debtInAvax is the first guess that provides a withdrtawalPool price
   * that is between limits of slippage when buyback&burn.
   */
  function planetPBalance(uint256 planetId)
    external
    view
    virtual
    override
    returns (uint256)
  {
    return DATASTORE.readUintForId(planetId, "pBalance");
  }

  /**
   * @notice An Operator is expected to pay for the DEBT of a staking pool
   * @dev msg.value-debt is put to surplus, this can be used to increase surplus without minting new tokens!! useful to claim fees
   */
  function payDebt(uint256 planetId, uint256 operatorId)
    external
    payable
    virtual
    override
    nonReentrant
    whenNotPaused
  {
    STAKEPOOL.payDebt(DATASTORE, planetId, operatorId);
  }

  /**
   * @notice operators can not claim fees if: expired OR deactivated
   * @notice current unclaimedFees are not allowed to be claimed as surplus
   * @return success if transfer of funds is succesful
   */
  function claimSurplus(uint256 planetId)
    external
    virtual
    override
    whenNotPaused
    nonReentrant
    returns (bool success)
  {
    success = StakeUtils.claimSurplus(
      DATASTORE,
      planetId,
      DATASTORE.readUintForId(planetId, "activeOperator")
    );
    require(success, "Portal: Failed to send surplus");
  }

  /**
   * @notice anyone can call this function, but it sends AVAX only to maintainer.
   * @notice reverts if there are not enough surplus.
   */
  function claimFee(uint256 planetId, uint256 claimerId)
    external
    virtual
    override
    whenNotPaused
    nonReentrant
    returns (uint256 feeSent)
  {
    feeSent = StakeUtils.claimFee(DATASTORE, planetId, claimerId);
  }

  /**
   *                                          ** Staking Pools **
   */
  function isStakingPausedForPool(uint256 _id)
    external
    view
    virtual
    override
    returns (bool)
  {
    return StakeUtils.isStakingPausedForPool(DATASTORE, _id);
  }

  /// @notice when a pool is paused there are NO new funds to be minted, NO surplus.
  function pauseStakingForPool(uint256 _id) external virtual override {
    StakeUtils.pauseStakingForPool(DATASTORE, _id);
  }

  function unpauseStakingForPool(uint256 _id) external virtual override {
    StakeUtils.unpauseStakingForPool(DATASTORE, _id);
  }

  function stake(
    uint256 planetId,
    uint256 minGavax,
    uint256 deadline
  )
    external
    payable
    virtual
    override
    whenNotPaused
    nonReentrant
    returns (uint256 totalgAvax)
  {
    totalgAvax = STAKEPOOL.stake(DATASTORE, planetId, minGavax, deadline);
    require(totalgAvax > 0, "Portal: unsuccesful deposit");
  }

  uint256[45] private __gap;
}
