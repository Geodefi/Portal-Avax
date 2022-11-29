// SPDX-License-Identifier: MIT
pragma solidity =0.8.7;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "../../interfaces/ISwap.sol";
import "../../interfaces/IgAVAX.sol";
import "../../WithdrawalPool/LPToken.sol";
import "./DataStoreLib.sol";

/**
 * @title StakeUtils library
 * @notice Exclusively contains functions related to Avax Liquid Staking designed by Geode Finance
 * @notice biggest part of the functionality is related to Withdrawal Pools
 * which relies on continuous buybacks for price peg with DEBT/SURPLUS calculations
 * @dev Contracts relying on this library must initialize StakeUtils.StakePool
 * @dev ALL "fee" variables are limited by FEE_DENOMINATOR = 100%
 * Note *suggested* refer to GeodeUtils before reviewing
 * Note refer to DataStoreUtils before reviewing
 * Note beware of the staking pool and operator implementations:
 * Operatores have properties like accumulatedFee, fee(as a percentage), maintainer.
 * Every staking pool(aka planet) is also an operator by design.
 * Planets(type 5) inherit operators (type 4), with additional properties like staking pools -relates to
 * params: pBalance, surplus, unclaimedFees-, withdrawal pool - relates to debt - and liquid asset(gAvax).
 */
library StakeUtils {
  using DataStoreUtils for DataStoreUtils.DataStore;

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

  /**
   * @notice StakePool includes the parameters related to Staking Pool Contracts.
   * @notice A staking pool works with a *bound* Withdrawal Pool to create best pricing
   * for the staking derivative. Withdrawal Pools uses StableSwap algorithm.
   * @param gAVAX ERC1155 contract that keeps the totalSupply, pricepershare and balances of all StakingPools by ID
   * @dev  gAVAX should not be changed ever!
   * @param DEFAULT_SWAP_POOL STABLESWAP pool that will be cloned to be used as Withdrawal Pool of given ID
   * @param DEFAULT_LP_TOKEN LP token implementation that will be cloned to be used for Withdrawal Pool of given ID
   * @param ORACLE https://github.com/Geodefi/Telescope
   * @param DEFAULT_A Withdrawal Pool parameter
   * @param DEFAULT_FEE Withdrawal Pool parameter
   * @param DEFAULT_ADMIN_FEE Withdrawal Pool parameter
   * @param FEE_DENOMINATOR represents 100% ALSO Withdrawal Pool parameter
   * @param MAX_MAINTAINER_FEE : limits operator.fee and planet.fee, set by GOVERNANCE
   * @dev changing any of address parameters (gAVAX, ORACLE, DEFAULT_SWAP_POOL, DEFAULT_LP_TOKEN) MUST require a contract upgrade to ensure security
   **/
  struct StakePool {
    address gAVAX;
    address DEFAULT_SWAP_POOL;
    address DEFAULT_LP_TOKEN;
    address ORACLE;
    uint256 DEFAULT_A;
    uint256 DEFAULT_FEE;
    uint256 DEFAULT_ADMIN_FEE;
    uint256 FEE_DENOMINATOR;
    uint256 PERIOD_PRICE_INCREASE_LIMIT;
    uint256 MAX_MAINTAINER_FEE;
  }

  /**
   * @notice gAVAX lacks *decimals*,
   * @dev gAVAX_DENOMINATOR makes sure that we are taking care of decimals on calculations related to gAVAX
   */
  uint256 public constant gAVAX_DENOMINATOR = 1e18;

  /// @notice Oracle is active for the first 30 min for a day
  uint256 public constant ORACLE_PERIOD = 1 days;
  uint256 public constant ORACLE_ACTIVE_PERIOD = 30 minutes;
  uint256 public constant DEACTIVATION_PERIOD = 15 days;
  uint256 public constant IGNORABLE_DEBT = 1 ether;

  /**
   * @notice whenever an operator is activated for a staking pool, it sets an activationExpiration date, which
   * means the op pay debt by burning gAvax tokens and collect fee from their validators.
   * While this implementation allows any two different ids to cooperate, with multiple interactions at any given time,
   * there can only be "1" activeOperator who can also claimSurplus to create new validators.
   */
  modifier beforeActivationExpiration(
    DataStoreUtils.DataStore storage _DATASTORE,
    uint256 _poolId,
    uint256 _claimerId
  ) {
    require(
      _DATASTORE.readUintForId(
        _poolId,
        bytes32(keccak256(abi.encodePacked(_claimerId, "activationExpiration")))
      ) > block.timestamp,
      "StakeUtils: operatorId activationExpiration has past"
    );
    _;
  }

  modifier onlyMaintainer(
    DataStoreUtils.DataStore storage _DATASTORE,
    uint256 _id
  ) {
    require(
      _DATASTORE.readAddressForId(_id, "maintainer") == msg.sender,
      "StakeUtils: sender not maintainer"
    );
    _;
  }

  function _clone(address target) public returns (address) {
    return Clones.clone(target);
  }

  function getgAVAX(StakePool storage self) public view returns (IgAVAX) {
    return IgAVAX(self.gAVAX);
  }

  /**
   * @notice                      ** Maintainer specific functions **
   *
   * @note "Maintainer" is a shared logic like "fee" by both operator and pools.
   * Maintainers have permissiones to maintain the given id like setting a new fee or interface as
   * well as paying debt etc. for operators.
   * @dev maintainer is set by CONTROLLER of given id
   */

  /// @notice even if MAX_MAINTAINER_FEE is decreased later, it returns limited maximum
  function getMaintainerFee(
    StakePool storage self,
    DataStoreUtils.DataStore storage _DATASTORE,
    uint256 _id
  ) public view returns (uint256) {
    return
      _DATASTORE.readUintForId(_id, "fee") > self.MAX_MAINTAINER_FEE
        ? self.MAX_MAINTAINER_FEE
        : _DATASTORE.readUintForId(_id, "fee");
  }

  function setMaintainerFee(
    StakePool storage self,
    DataStoreUtils.DataStore storage _DATASTORE,
    uint256 _id,
    uint256 _newFee
  ) external onlyMaintainer(_DATASTORE, _id) {
    require(
      _newFee <= self.MAX_MAINTAINER_FEE,
      "StakeUtils: MAX_MAINTAINER_FEE ERROR"
    );
    _DATASTORE.writeUintForId(_id, "fee", _newFee);
    emit MaintainerFeeUpdated(_id, _newFee);
  }

  function setMaxMaintainerFee(StakePool storage self, uint256 _newMaxFee)
    external
  {
    require(
      _newMaxFee <= self.FEE_DENOMINATOR,
      "StakeUtils: fee more than 100%"
    );
    self.MAX_MAINTAINER_FEE = _newMaxFee;
    emit MaxMaintainerFeeUpdated(_newMaxFee);
  }

  function changeMaintainer(
    DataStoreUtils.DataStore storage _DATASTORE,
    uint256 _id,
    address _newMaintainer
  ) external {
    require(
      _DATASTORE.readAddressForId(_id, "CONTROLLER") == msg.sender,
      "StakeUtils: not CONTROLLER of given id"
    );
    require(
      _newMaintainer != address(0),
      "StakeUtils: maintainer can not be zero"
    );

    _DATASTORE.writeAddressForId(_id, "maintainer", _newMaintainer);
  }

  /**
   * @notice                      ** Staking Pool specific functions **
   */

  /// @notice mints gAVAX tokens with given ID and amount.
  /// @dev shouldn't be accesible publicly
  function _mint(
    address _gAVAX,
    address _to,
    uint256 _id,
    uint256 _amount
  ) internal {
    require(_id > 0, "StakeUtils: _mint id should be > 0");
    IgAVAX(_gAVAX).mint(_to, _id, _amount, "");
  }

  /**
   * @notice conducts a buyback using the given withdrawal pool,
   * @param to address to send bought gAVAX(id). burns the tokens if to=address(0), transfers if not
   * @param poolId id of the gAVAX that will be bought
   * @param sellAvax AVAX amount to sell
   * @param minToBuy TX is expected to revert by Swap.sol if not meet
   * @param deadline TX is expected to revert by Swap.sol if deadline has past
   * @dev this function assumes that pool is deployed by deployWithdrawalPool
   * as index 0 is avax and index 1 is Gavax
   */
  function _buyback(
    StakePool storage self,
    DataStoreUtils.DataStore storage _DATASTORE,
    address to,
    uint256 poolId,
    uint256 sellAvax,
    uint256 minToBuy,
    uint256 deadline
  ) internal returns (uint256 outAmount) {
    // SWAP in WP
    outAmount = withdrawalPoolById(_DATASTORE, poolId).swap{ value: sellAvax }(
      0,
      1,
      sellAvax,
      minToBuy,
      deadline
    );
    if (to == address(0)) {
      // burn
      getgAVAX(self).burn(address(this), poolId, outAmount);
    } else {
      // send back to user
      getgAVAX(self).safeTransferFrom(address(this), to, poolId, outAmount, "");
    }
  }

  /**
   * @notice                      ** ORACLE specific functions **
   */

  /**
   * @notice sets pricePerShare parameter of gAVAX(id)
   * @dev only ORACLE should be able to reach this after sanity checks on new price
   */
  function _setPricePerShare(
    StakePool storage self,
    uint256 pricePerShare_,
    uint256 _id
  ) internal {
    require(_id > 0, "StakeUtils: id should be > 0");
    getgAVAX(self).setPricePerShare(pricePerShare_, _id);
    emit PriceChanged(_id, pricePerShare_);
  }

  /**
   * @notice Oracle is only allowed for a period every day & pool operations are stopped then
   * @return false if the last oracle update happened already (within the current daily period)
   */
  function _isOracleActive(
    DataStoreUtils.DataStore storage _DATASTORE,
    uint256 _poolId
  ) internal view returns (bool) {
    return
      (block.timestamp % ORACLE_PERIOD <= ORACLE_ACTIVE_PERIOD) &&
      (_DATASTORE.readUintForId(_poolId, "oracleUpdateTimeStamp") <
        block.timestamp - ORACLE_ACTIVE_PERIOD);
  }

  /**
   * @notice oraclePrice is a reliable source for any contract operation
   * @dev also the *mint price* when there is a no debt
   */
  function oraclePrice(StakePool storage self, uint256 _id)
    public
    view
    returns (uint256 _oraclePrice)
  {
    _oraclePrice = getgAVAX(self).pricePerShare(_id);
  }

  /**
   * @notice in order to prevent attacks from malicious Oracle there are boundaries to price & fee updates.
   * @dev checks:
   * 1. Price should be increased & it should not be increased more than PERIOD_PRICE_INCREASE_LIMIT
   *  with the factor of how many days since oracleUpdateTimeStamp has past.
   *  To encourage report oracle each day, price increase limit is not calculated by considering compound effect
   *  for multiple days.
   */
  function _sanityCheck(
    StakePool storage self,
    DataStoreUtils.DataStore storage _DATASTORE,
    uint256 _id,
    uint256 _newPrice
  ) internal view {
    // need to put the lastPriceUpdate to DATASTORE to check if price is updated already for that day
    uint256 periodsSinceUpdate = (block.timestamp +
      ORACLE_ACTIVE_PERIOD -
      _DATASTORE.readUintForId(_id, "oracleUpdateTimeStamp")) / ORACLE_PERIOD;
    uint256 curPrice = oraclePrice(self, _id);
    uint256 maxPrice = curPrice +
      ((curPrice * self.PERIOD_PRICE_INCREASE_LIMIT * periodsSinceUpdate) /
        self.FEE_DENOMINATOR);

    require(
      _newPrice <= maxPrice && _newPrice >= curPrice,
      "StakeUtils: price did NOT met"
    );
  }

  /**
   * @notice distribute fees to given operator Ids, by related to their fees.
   * Finally, distribute the fee of maintainer of the pool from total amounts.
   *
   * @dev fees can be higher than current MAX, if MAX is changed afterwards, we check that condition.
   */
  function _distributeFees(
    StakePool storage self,
    DataStoreUtils.DataStore storage _DATASTORE,
    uint256 _poolId,
    uint256[] calldata _opIds,
    uint256[] calldata _pBalanceIncreases
  ) internal returns (uint256 totalPBalanceIncrease, uint256 totalFees) {
    require(
      _opIds.length == _pBalanceIncreases.length,
      "StakeUtils: Array lengths doesn't match"
    );

    for (uint256 i = 0; i < _opIds.length; i++) {
      // do not double spend if pool maintainer is also maintaining the validators
      if (_opIds[i] != _poolId) {
        // below require checks activationExpiration[keccak256(abi.encodePacked(_id, operator))] logic
        require(
          _DATASTORE.readUintForId(
            _poolId,
            bytes32(
              keccak256(abi.encodePacked(_opIds[i], "activationExpiration"))
            )
          ) > block.timestamp - ORACLE_PERIOD,
          "StakeUtils: _opId activationExpiration has past"
        );
        uint256 opFee = getMaintainerFee(self, _DATASTORE, _opIds[i]);
        (uint256 _fee, bytes32 _key) = accumulatedFee(
          _DATASTORE,
          _poolId,
          _opIds[i]
        );
        uint256 gainedOpFee = (opFee * _pBalanceIncreases[i]) /
          self.FEE_DENOMINATOR;
        _DATASTORE.writeUintForId(_poolId, _key, _fee + gainedOpFee);
        totalFees += gainedOpFee;
      }
      totalPBalanceIncrease += _pBalanceIncreases[i];
    }

    // op_fee * _pBalanceIncrease[i] to calculate respective fee from the gained increase
    uint256 poolFee = getMaintainerFee(self, _DATASTORE, _poolId);
    uint256 gainedPoolFee = (poolFee * totalPBalanceIncrease) /
      self.FEE_DENOMINATOR;

    (uint256 fee, bytes32 key) = accumulatedFee(_DATASTORE, _poolId, _poolId);
    totalFees += gainedPoolFee;
    _DATASTORE.writeUintForId(_poolId, key, fee + gainedPoolFee);
  }

  /**
   * @notice only Oracle can report a new price. However price is not purely calculated by it.
   * the balance on P subchain is estimated by it, including the unrealized staking rewards.
   * Oracle has a pessimistic approach to make sure price will not decrease by a lot even in the case of loss of funds.

   * @param _reportedTimeStamp ensures prepeared report is prepeared within last activation period, prevent previous reports to be accepted. 
   * @param _opIds all ids of all operators who still collect fees.
   * @param _pBalanceIncreases the amount of avax that has been gained by the operator as POS rewards, respective to _opIds
   * @dev simply the new price is found by (pBALANCE + surplus - fees) / totalSupply)
   * @return price : new price after sanitychecks, might be useful if onchain oracle in the future
   */
  function reportOracle(
    StakePool storage self,
    DataStoreUtils.DataStore storage _DATASTORE,
    uint256 _reportedTimeStamp,
    uint256 _poolId,
    uint256[] calldata _opIds,
    uint256[] calldata _pBalanceIncreases
  ) external returns (uint256 price) {
    require(msg.sender == self.ORACLE, "StakeUtils: msg.sender NOT oracle");
    require(
      _isOracleActive(_DATASTORE, _poolId),
      "StakeUtils: Oracle is NOT active"
    );
    require(
      _reportedTimeStamp >= block.timestamp - ORACLE_ACTIVE_PERIOD,
      "StakeUtils: Reported timestamp is NOT valid"
    );

    // distribute fees
    (uint256 totalPBalanceIncrease, uint256 totalFees) = _distributeFees(
      self,
      _DATASTORE,
      _poolId,
      _opIds,
      _pBalanceIncreases
    );

    uint256 newPBalance = _DATASTORE.readUintForId(_poolId, "pBalance") +
      totalPBalanceIncrease;
    _DATASTORE.writeUintForId(_poolId, "pBalance", newPBalance);

    uint256 unclaimed = _DATASTORE.readUintForId(_poolId, "unclaimedFees") +
      totalFees;
    _DATASTORE.writeUintForId(_poolId, "unclaimedFees", unclaimed);

    // deduct unclaimed fees from surplus
    price =
      ((newPBalance +
        _DATASTORE.readUintForId(_poolId, "surplus") -
        unclaimed) * gAVAX_DENOMINATOR) /
      (getgAVAX(self).totalSupply(_poolId));
    _sanityCheck(self, _DATASTORE, _poolId, price);
    _setPricePerShare(self, price, _poolId);

    _DATASTORE.writeUintForId(
      _poolId,
      "oracleUpdateTimeStamp",
      block.timestamp
    );
    emit OracleUpdate(
      _poolId,
      price,
      newPBalance,
      totalFees,
      _reportedTimeStamp
    );
  }

  /**
   * @notice                      ** DEBT/SURPLUS/FEE specific functions **
   */

  /**
   * @notice When a pool maintainer wants another operator's maintainer to be able to start claiming surplus and
   * creating validators, it activates the validator.
   * @notice Changes activeOperator of the given ID; old activeOperator can NOT claim surplus anymore
   * @dev However it can still continue holding its old balance until activationExpiration, and gain fees
   * @dev activationExpiration timestamp until new activeoperator continues getting fees from id's staking pool
   */
  function activateOperator(
    DataStoreUtils.DataStore storage _DATASTORE,
    uint256 _id,
    uint256 _activeId
  ) external onlyMaintainer(_DATASTORE, _id) returns (bool) {
    _DATASTORE.writeUintForId(_id, "activeOperator", _activeId);
    _DATASTORE.writeUintForId(
      _id,
      bytes32(keccak256(abi.encodePacked(_activeId, "activationExpiration"))),
      type(uint256).max
    );
    emit OperatorActivated(_id, _activeId);
    return true;
  }

  /**
   * @notice deactivates an old operator for the given staking pool
   * @dev when activationExpiration is up, operator will NOT be able generate fees from pool,
   * it is expected for them to return the assets as surplus with payDebt function
   * @dev _deactivateAfter seconds until activation expires,
   */
  function deactivateOperator(
    DataStoreUtils.DataStore storage _DATASTORE,
    uint256 _id,
    uint256 _deactivedId
  ) external onlyMaintainer(_DATASTORE, _id) returns (bool) {
    if (_DATASTORE.readUintForId(_id, "activeOperator") == _deactivedId)
      _DATASTORE.writeUintForId(_id, "activeOperator", 0);

    _DATASTORE.writeUintForId(
      _id,
      bytes32(
        keccak256(abi.encodePacked(_deactivedId, "activationExpiration"))
      ),
      block.timestamp + DEACTIVATION_PERIOD //15 days
    );
    emit OperatorDeactivated(_id, _deactivedId);
    return true;
  }

  /**
   * @notice Only an Operator is expected to pay for the DEBT of a staking pool.
   * When it is paid, p subChain balance decreases, effectively changing the price calculations!
   */
  function payDebt(
    StakePool storage self,
    DataStoreUtils.DataStore storage _DATASTORE,
    uint256 _poolId,
    uint256 _operatorId
  )
    external
    onlyMaintainer(_DATASTORE, _operatorId)
    beforeActivationExpiration(_DATASTORE, _poolId, _operatorId)
  {
    require(
      !_isOracleActive(_DATASTORE, _poolId),
      "StakeUtils: Oracle is active"
    );

    //mgs.value should be bigger than 0 for everything to make sense
    require(msg.value > 0, "StakeUtils: no avax is sent");

    // msg.value is assined to value, value is the variable to keep how much left in my hand to continue
    // paying the rest of the debts and or how much left after paying the debts to put the rest in to surplus
    uint256 value = msg.value;
    uint256 surplus = _DATASTORE.readUintForId(_poolId, "surplus");
    uint256 unclaimedFees = _DATASTORE.readUintForId(_poolId, "unclaimedFees");

    // this if statement checks if there is a operation fee that needs to be paid.
    // If distributed fee exceeds the surplus, there is a gap between fees and surplus
    // so we check if the unclaimedFees are bigger than surplus.
    if (unclaimedFees > surplus) {
      // the difference between unclaimedFees and the surplus is the debt for the fees.
      uint256 debtInFees = unclaimedFees - surplus;

      // need to check if the debtInFees is bigger than the value, if not, can only pay value amount of debtInFees
      // if not, we are paying all debtInFees by adding it to the surplus so that the difference might be 0(zero) after this action.
      if (debtInFees > value) {
        debtInFees = value;
      }

      // we pay for the debtInFees as we can
      surplus += debtInFees;

      // we substract the debtInFees from value since we cannot use that amount to pay the rest, it is already gone.
      value -= debtInFees;
    }

    // we check if remaining value is bigger than 0 to save gas, because it may be already used
    if (value > 0) {
      // we get the debt from the withdrawal pool
      uint256 debtToBurn = withdrawalPoolById(_DATASTORE, _poolId).getDebt();
      // to save the gas we make sure that it is bigger then an ignorably low amount while we are doing a buyback
      if (debtToBurn > IGNORABLE_DEBT) {
        // same idea with the fee debt and values
        if (debtToBurn > value) {
          debtToBurn = value;
        }

        // burns
        _buyback(
          self,
          _DATASTORE,
          address(0),
          _poolId,
          debtToBurn,
          0,
          type(uint256).max
        );

        // we substract the debt from value to see how much left if there is any left to put it on surplus
        value -= debtToBurn;
      }
    }

    _DATASTORE.writeUintForId(_poolId, "surplus", surplus + value);

    // in all cases, if we pass the require msg.value > 0, that money is coming from the p chain
    // and we need to decrease the pBalance for msg.value amount
    uint256 pBalance = _DATASTORE.readUintForId(_poolId, "pBalance");
    if (pBalance > msg.value) {
      _DATASTORE.writeUintForId(_poolId, "pBalance", pBalance - msg.value);
    } else {
      _DATASTORE.writeUintForId(_poolId, "pBalance", 0);
    }

    emit debtPaid(_poolId, _operatorId, msg.value);
  }

  /**
   * @notice only authorized Operator is expected to claim the surplus of a staking pool
   * @notice current fees are not allowed to be claimed from surplus,
   * however oracle update can also make it hard since it increases unclaimedFees without touching the surplus
   */
  function claimSurplus(
    DataStoreUtils.DataStore storage _DATASTORE,
    uint256 _poolId,
    uint256 _claimerId
  )
    external
    onlyMaintainer(_DATASTORE, _claimerId)
    beforeActivationExpiration(_DATASTORE, _poolId, _claimerId)
    returns (bool)
  {
    require(
      !_isOracleActive(_DATASTORE, _poolId),
      "StakeUtils: Oracle is active"
    );
    uint256 fees = _DATASTORE.readUintForId(_poolId, "unclaimedFees");
    uint256 surplus = _DATASTORE.readUintForId(_poolId, "surplus");
    require(surplus > fees, "StakeUtils: pool fees exceed surplus");
    _DATASTORE.writeUintForId(_poolId, "surplus", fees);

    uint256 currentPBal = _DATASTORE.readUintForId(_poolId, "pBalance");
    _DATASTORE.writeUintForId(
      _poolId,
      "pBalance",
      currentPBal + surplus - fees
    );

    (bool sent, ) = payable(
      _DATASTORE.readAddressForId(_claimerId, "maintainer")
    ).call{ value: surplus - fees }("");
    require(sent, "StakeUtils: Failed to send Avax");
    emit SurplusClaimed(_poolId, surplus - fees);
    return sent;
  }

  /**
   * @notice accumulatedFee is stored with a key combines the poolId, claimerId & "accumulatedFee"
   * @dev function also returns the key for ease of use, please use.
   */
  function accumulatedFee(
    DataStoreUtils.DataStore storage _DATASTORE,
    uint256 poolId,
    uint256 claimerId
  ) public view returns (uint256 fee, bytes32 key) {
    key = bytes32(keccak256(abi.encodePacked(claimerId, "accumulatedFee")));
    fee = _DATASTORE.readUintForId(poolId, key);
  }

  /**
   * @notice anyone can call this function, but it sends AVAX to maintainer.
   * @notice reverts if there are not enough surplus.
   */
  function claimFee(
    DataStoreUtils.DataStore storage _DATASTORE,
    uint256 poolId,
    uint256 claimerId
  )
    external
    beforeActivationExpiration(_DATASTORE, poolId, claimerId)
    returns (uint256 feeToSend)
  {
    require(
      !_isOracleActive(_DATASTORE, poolId),
      "StakeUtils: Oracle is active"
    );
    (uint256 fee, bytes32 key) = accumulatedFee(_DATASTORE, poolId, claimerId);

    uint256 surplus = _DATASTORE.readUintForId(poolId, "surplus");
    require(
      fee > 0 && surplus > 0,
      "StakeUtils: fee and surplus should be bigger than zero"
    );

    feeToSend = fee > surplus ? surplus : fee;
    _DATASTORE.writeUintForId(poolId, "surplus", surplus - feeToSend);
    uint256 _unclaimedFees = _DATASTORE.readUintForId(poolId, "unclaimedFees");

    _DATASTORE.writeUintForId(
      poolId,
      "unclaimedFees",
      _unclaimedFees - feeToSend
    );

    address receiver = payable(
      _DATASTORE.readAddressForId(claimerId, "maintainer")
    );

    // set the accumulatedFee to zero
    _DATASTORE.writeUintForId(poolId, key, fee - feeToSend);

    (bool sent, ) = receiver.call{ value: feeToSend }("");
    require(sent, "StakeUtils: Failed to send Avax");
    emit FeeClaimed(poolId, claimerId, feeToSend);
  }

  /**
   * @notice                      ** WITHDRAWAL POOL specific functions **
   */

  function isStakingPausedForPool(
    DataStoreUtils.DataStore storage _DATASTORE,
    uint256 _id
  ) public view returns (bool) {
    // minting is paused when length != 0
    return _DATASTORE.readBytesForId(_id, "stakePaused").length != 0;
  }

  /**
   * @notice pausing only prevents new staking operations.
   * when a pool is paused for staking there are NO new funds to be minted, NO surplus.
   */
  function pauseStakingForPool(
    DataStoreUtils.DataStore storage _DATASTORE,
    uint256 _id
  ) external onlyMaintainer(_DATASTORE, _id) {
    _DATASTORE.writeBytesForId(_id, "stakePaused", bytes("1")); // meaning true, importantly length > 0
    emit PausedPool(_id);
  }

  function unpauseStakingForPool(
    DataStoreUtils.DataStore storage _DATASTORE,
    uint256 _id
  ) external onlyMaintainer(_DATASTORE, _id) {
    _DATASTORE.writeBytesForId(_id, "stakePaused", bytes("")); // meaning false, importantly length = 0
    emit UnpausedPool(_id);
  }

  function withdrawalPoolById(
    DataStoreUtils.DataStore storage _DATASTORE,
    uint256 _id
  ) public view returns (ISwap) {
    return ISwap(_DATASTORE.readAddressForId(_id, "withdrawalPool"));
  }

  function LPTokenById(DataStoreUtils.DataStore storage _DATASTORE, uint256 _id)
    public
    view
    returns (LPToken)
  {
    return LPToken(_DATASTORE.readAddressForId(_id, "LPToken"));
  }

  /**
   * @notice deploys a new withdrawal pool using DEFAULT_SWAP_POOL
   * @dev sets the withdrawal pool with respective
   */
  function deployWithdrawalPool(
    StakePool storage self,
    DataStoreUtils.DataStore storage _DATASTORE,
    uint256 _id
  ) external returns (address WithdrawalPool) {
    require(_id > 0, "StakeUtils: id should be > 0");
    require(
      _DATASTORE.readAddressForId(_id, "withdrawalPool") == address(0),
      "StakeUtils: withdrawalPool already exists"
    );

    WithdrawalPool = _clone(self.DEFAULT_SWAP_POOL);

    address _LPToken = ISwap(WithdrawalPool).initialize(
      address(getgAVAX(self)),
      _id,
      string(
        abi.encodePacked(
          _DATASTORE.readBytesForId(_id, "name"),
          "-Geode WP Token"
        )
      ),
      string(abi.encodePacked(_DATASTORE.readBytesForId(_id, "name"), "-WP")),
      self.DEFAULT_A,
      self.DEFAULT_FEE,
      self.DEFAULT_ADMIN_FEE,
      self.DEFAULT_LP_TOKEN
    );

    // initially 1 AVAX = 1 gAVAX
    _setPricePerShare(self, 1 ether, _id);
    _DATASTORE.writeAddressForId(_id, "withdrawalPool", WithdrawalPool);
    _DATASTORE.writeAddressForId(_id, "LPToken", _LPToken);

    // approve token so we can use it in buybacks
    getgAVAX(self).setApprovalForAll(WithdrawalPool, true);
    LPTokenById(_DATASTORE, _id).approve(WithdrawalPool, type(uint256).max);
  }

  /**
   * @notice staking function. buys if price is low, mints new tokens if a surplus is sent (extra avax through msg.value)
   * @param poolId id of the staking pool, withdrawal pool and gAVAX to be used.
   * @param minGavax swap op param
   * @param deadline swap op param
    // d  m.v
    // 100 10 => buyback
    // 100 100  => buyback
    // 10 100  =>  buyback + mint
    // 0 x => mint
   */
  function stake(
    StakePool storage self,
    DataStoreUtils.DataStore storage _DATASTORE,
    uint256 poolId,
    uint256 minGavax,
    uint256 deadline
  ) external returns (uint256 totalgAvax) {
    require(msg.value > 0, "GeodePortal: no avax given");
    require(
      !isStakingPausedForPool(_DATASTORE, poolId),
      "StakeUtils: minting is paused"
    );
    uint256 debt = withdrawalPoolById(_DATASTORE, poolId).getDebt();
    if (debt >= msg.value) {
      return
        _buyback(
          self,
          _DATASTORE,
          msg.sender,
          poolId,
          msg.value,
          minGavax,
          deadline
        );
    } else {
      uint256 boughtGavax = 0;
      uint256 remAvax = msg.value;
      if (debt > IGNORABLE_DEBT) {
        boughtGavax = _buyback(
          self,
          _DATASTORE,
          msg.sender,
          poolId,
          debt,
          0,
          deadline
        );
        remAvax -= debt;
      }
      uint256 mintGavax = (
        ((remAvax * gAVAX_DENOMINATOR) / oraclePrice(self, poolId))
      );
      _mint(self.gAVAX, msg.sender, poolId, mintGavax);
      _DATASTORE.writeUintForId(
        poolId,
        "surplus",
        _DATASTORE.readUintForId(poolId, "surplus") + remAvax
      );
      require(
        boughtGavax + mintGavax >= minGavax,
        "StakeUtils: less than minGavax"
      );
      return boughtGavax + mintGavax;
    }
  }
}
