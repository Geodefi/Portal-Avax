// SPDX-License-Identifier: MIT
pragma solidity =0.8.7;
import "./helpers/ERC1155SupplyMinterPauser.sol";

/**
 * @title Geode Finance geode-avax: gAVAX
 * gAVAX is a special ERC1155 contract with additional functionalities.
 * One of the unique functionalities are the included price logic that tracks the underlaying ratio with
 * staked asset, AVAX.
 * Other and most important change is the implementation of ERC1155Interfaces.
 * This addition effectively result in changes in safeTransferFrom(), burn(), _doSafeTransferAcceptanceCheck()
 * functions, reasoning is in the comments.
 * @dev recommended to check helpers/ERC1155SupplyMinterPauser.sol first
 */

contract gAVAX is ERC1155SupplyMinterPauser {
  using Address for address;
  event InterfaceChanged(address indexed newInterface, uint256 ID);

  bytes32 public constant ORACLE_ROLE = keccak256("ORACLE_ROLE");
  string public constant name = "Geode Staked AVAX";
  string public constant symbol = "gAVAX";

  /**
   * @dev ADDED for gAVAX
   * @notice Mapping from planet IDs to ERC1155interface implementation addresses
   * There can be multiple Interfaces for 1 planet(staking pool).
   **/
  mapping(uint256 => mapping(address => bool)) private _interfaces;

  /**
   * @dev ADDED for gAVAX
   * @notice shows the underlying AVAX for 1 staked gAVAX for a given asset id
   * @dev freshly assigned ids should return 1e18 since initally 1 AVAX = 1 gAVAX
   **/
  mapping(uint256 => uint256) private _pricePerShare;

  constructor(string memory uri) ERC1155SupplyMinterPauser(uri) {
    _setupRole(ORACLE_ROLE, _msgSender());
  }

  /**
   * @dev ADDED for gAVAX
   * @notice checks if an address is defined as an interface for the given Planet id.
   */
  function isInterface(address _interface, uint256 id)
    public
    view
    virtual
    returns (bool)
  {
    require(
      _interface != address(0),
      "gAVAX: interface query for the zero address"
    );

    return _interfaces[id][_interface];
  }

  /**
   * @dev ADDED for gAVAX
   * @dev only authorized parties should set the interface as this is super crucial.
   */
  function _setInterface(
    address _Interface,
    uint256 _id,
    bool isSet
  ) internal virtual {
    require(
      _Interface != address(0),
      "gAVAX: interface query for the zero address"
    );

    _interfaces[_id][_Interface] = isSet;
  }

  /**
   * @dev ADDED for gAVAX
   * @notice to be used to set an an address of a contract that will
   * be behaved as an interface by gAVAX contract for a spesific ID
   */
  function setInterface(
    address _Interface,
    uint256 _id,
    bool isSet
  ) external virtual {
    require(
      hasRole(MINTER_ROLE, _msgSender()),
      "gAVAX: must have MINTER_ROLE to set"
    );
    require(_Interface.isContract(), "gAVAX: _Interface must be a contract");

    _setInterface(_Interface, _id, isSet);

    emit InterfaceChanged(_Interface, _id);
  }

  /**
   * @dev ADDED for gAVAX
   */
  function pricePerShare(uint256 _id) external view returns (uint256) {
    return _pricePerShare[_id];
  }

  /**
   * @dev ADDED for gAVAX
   */
  function _setPricePerShare(uint256 pricePerShare_, uint256 _id)
    internal
    virtual
  {
    _pricePerShare[_id] = pricePerShare_;
  }

  function setPricePerShare(uint256 pricePerShare_, uint256 _id)
    external
    virtual
  {
    require(
      hasRole(ORACLE_ROLE, _msgSender()),
      "gAVAX: must have ORACLE to set"
    );

    _setPricePerShare(pricePerShare_, _id);
  }

  /**
   * @notice updates the authorized party for all crucial operations related to
   * minting, pricing and interfaces.
   * @dev MinterPauserOracle is basically a superUser, there can be only 1 at a given time,
   * intended as "Portal"
   */
  function updateMinterPauserOracle(address Minter) external virtual {
    require(
      hasRole(MINTER_ROLE, _msgSender()),
      "gAVAX: must have MINTER_ROLE to set"
    );

    renounceRole(MINTER_ROLE, _msgSender());
    renounceRole(PAUSER_ROLE, _msgSender());
    renounceRole(ORACLE_ROLE, _msgSender());

    _setupRole(MINTER_ROLE, Minter);
    _setupRole(PAUSER_ROLE, Minter);
    _setupRole(ORACLE_ROLE, Minter);
  }

  /**
   * @dev See {IERC1155-safeTransferFrom}.
   * @dev CHANGED for gAVAX
   * @dev interfaces can move your tokens without asking you.
   * @dev ADDED "|| isInterface(_msgSender(),id))"
   */
  function safeTransferFrom(
    address from,
    address to,
    uint256 id,
    uint256 amount,
    bytes memory data
  ) public virtual override {
    require(
      from == _msgSender() ||
        (isApprovedForAll(from, _msgSender()) || isInterface(_msgSender(), id)),
      "ERC1155: caller is not owner nor interface nor approved"
    );

    _safeTransferFrom(from, to, id, amount, data);
  }

  /**
   * @dev See {IERC1155-safeTransferFrom}.
   * @dev CHANGED for gAVAX
   * @dev ADDED "|| isInterface(_msgSender(),id))"
   */
  function burn(
    address account,
    uint256 id,
    uint256 value
  ) public virtual override {
    require(
      account == _msgSender() ||
        (isApprovedForAll(account, _msgSender()) ||
          isInterface(_msgSender(), id)),
      "ERC1155: caller is not owner nor interface nor approved"
    );

    _burn(account, id, value);
  }

  /**
   * @notice interfaces should handle their own Checks in the contract
   * @dev See {IERC1155-safeTransferFrom}.
   * @dev CHANGED for gAVAX
   * @dev ADDED "&& !isInterface(operator,id))"
   */
  function _doSafeTransferAcceptanceCheck(
    address operator,
    address from,
    address to,
    uint256 id,
    uint256 amount,
    bytes memory data
  ) internal virtual override {
    if (to.isContract() && !isInterface(operator, id)) {
      try
        IERC1155Receiver(to).onERC1155Received(operator, from, id, amount, data)
      returns (bytes4 response) {
        if (response != IERC1155Receiver.onERC1155Received.selector) {
          revert("ERC1155: ERC1155Receiver rejected tokens");
        }
      } catch Error(string memory reason) {
        revert(reason);
      } catch {
        revert("ERC1155: transfer to non ERC1155Receiver implementer");
      }
    }
  }
}
