// SPDX-License-Identifier: MIT
pragma solidity =0.8.7;
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

interface IERC20InterfaceUpgradable is IERC20Upgradeable {
  function initialize(
    uint256 id_,
    string memory name_,
    address _1155
  ) external;

  function increaseAllowance(address spender, uint256 addedValue)
    external
    returns (bool);

  function decreaseAllowance(address spender, uint256 subtractedValue)
    external
    returns (bool);

  function pricePerShare() external view returns (uint256);
}
