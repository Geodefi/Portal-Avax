// SPDX-License-Identifier: MIT
pragma solidity =0.8.7;
import "../Portal/utils/DataStoreLib.sol";
import "../Portal/utils/GeodeUtilsLib.sol";
import "../Portal/utils/StakeUtilsLib.sol";
import "../interfaces/IgAVAX.sol";

interface IPortal {
  function initialize(
    address _GOVERNANCE,
    address _ORACLE,
    address _gAVAX,
    address _DEFAULT_SWAP_POOL,
    address _DEFAULT_INTERFACE,
    address _DEFAULT_LP_TOKEN
  ) external;

  function pause() external;

  function unpause() external;

  function getVersion() external view returns (uint256);

  function gAVAX() external view returns (address);

  function getSenate() external view returns (address);

  function getGovernance() external view returns (address);

  function getOperationFee() external view returns (uint256);

  function getMaxOperationFee() external view returns (uint256);

  function getSenateExpireTimestamp() external view returns (uint256);

  function getFeeDenominator() external view returns (uint256);

  function getStakePoolParams()
    external
    view
    returns (StakeUtils.StakePool memory);

  function getIdsByType(uint256 _type) external view returns (uint256[] memory);

  function getIdFromName(string calldata _name)
    external
    pure
    returns (uint256 _id);

  function getNameFromId(uint256 _id) external view returns (bytes memory);

  function getCONTROLLERFromId(uint256 _id) external view returns (address);

  function getMaintainerFromId(uint256 _id) external view returns (address);

  function getMaintainerFeeFromId(uint256 _id) external view returns (uint256);

  function planetCurrentInterface(uint256 _id) external view returns (address);

  function planetWithdrawalPool(uint256 _id) external view returns (address);

  function planetLPToken(uint256 _id) external view returns (address);

  function planetActiveOperator(uint256 _id) external view returns (uint256);

  function changeIdCONTROLLER(uint256 _id, address _newCONTROLLER) external;

  function changeIdMaintainer(uint256 _id, address _newMaintainer) external;

  function setMaintainerFee(uint256 _id, uint256 _newFee) external;

  function setOperationFee(uint256 _newFee) external returns (bool success);

  function setMaxOperationFee(uint256 _newFee) external returns (bool success);

  function setMaxMaintainerFee(uint256 _newFee) external;

  function setDefaultInterface(address _newDefault) external;

  function activateOperator(uint256 _id, uint256 _activeId)
    external
    returns (bool);

  function deactivateOperator(uint256 _id, uint256 _deactivedId)
    external
    returns (bool);

  function setPlanetInterface(
    uint256 _id,
    address _Interface,
    bool isSet
  ) external;

  function setPBank(
    uint256 operatorId,
    uint256 planetId,
    bytes memory pBank
  ) external;

  function getPBank(uint256 operatorId, uint256 planetId)
    external
    view
    returns (bytes memory);

  function getProposal(uint256 id)
    external
    view
    returns (GeodeUtils.Proposal memory);

  function newProposal(
    address _CONTROLLER,
    uint256 _type,
    uint256 _proposalDuration,
    bytes calldata _name
  ) external;

  function approveProposal(uint256 _id) external;

  function approveSenate(uint256 proposalId, uint256 electorId) external;

  function planetOraclePrice(uint256 _id)
    external
    view
    returns (uint256 _pricePershare);

  function isOracleActive(uint256 _planetId) external view returns (bool);

  function reportOracle(
    uint256 _reportedTimeStamp,
    uint256 _planetId,
    uint256[] memory _opIds,
    uint256[] memory _pBalanceIncreases
  ) external returns (uint256 price);

  function planetSurplus(uint256 planetId) external view returns (uint256);

  function planetClaimableSurplus(uint256 planetId) external returns (uint256);

  function unclaimedFees(uint256 planetId) external view returns (uint256 fee);

  function accumulatedFee(uint256 planetId, uint256 claimerId)
    external
    view
    returns (uint256);

  function planetDebt(uint256 planetId)
    external
    view
    returns (uint256 debtInAvax);

  function planetPBalance(uint256 planetId) external view returns (uint256);

  function payDebt(uint256 planetId, uint256 operatorId) external payable;

  function claimSurplus(uint256 planetId) external returns (bool success);

  function claimFee(uint256 planetId, uint256 claimerId)
    external
    returns (uint256 feeToSend);

  function isStakingPausedForPool(uint256 _id) external view returns (bool);

  function pauseStakingForPool(uint256 id) external;

  function unpauseStakingForPool(uint256 id) external;

  function stake(
    uint256 planetId,
    uint256 minGavax,
    uint256 deadline
  ) external payable returns (uint256 totalgAvax);
}
