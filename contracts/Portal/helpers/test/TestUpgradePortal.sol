// SPDX-License-Identifier: MIT

pragma solidity =0.8.7;

import "../../Portal.sol";

contract PortalV2 is Portal {
  using DataStoreUtils for DataStoreUtils.DataStore;
  using GeodeUtils for GeodeUtils.Universe;
  using StakeUtils for StakeUtils.StakePool;
  uint256 private newParam;
  uint256 private constant newConstParam = 42;

  function initializeV2(uint256 _versionNumber) public virtual {
    require(CONTRACT_VERSION == 1);
    // getVersion
    CONTRACT_VERSION = _versionNumber;
    emit ContractVersionSet(CONTRACT_VERSION);
  }

  function setNewParam(uint256 value) public {
    newParam = value;
  }

  function getNewParam() public view returns (uint256) {
    return newParam;
  }

  function getNewConstParam() public pure returns (uint256) {
    return newConstParam;
  }

  function setNewParamOnlyGovernance(uint256 value) public onlyGovernance {
    newParam = value;
  }

  function getNewParamOnlyGovernance()
    public
    view
    onlyGovernance
    returns (uint256)
  {
    return newParam;
  }

  uint256[43] private __gap;
}
