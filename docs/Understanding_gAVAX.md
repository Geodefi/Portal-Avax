# Understanding gAVAX
 Creation of a Staking Pool requires only two main parameters:
-   Balances of the Stakers
-   Price of the yield bearing asset of the Pool

To achieve that every Staking Pool that is created with Geode Portal, uses a non-upgradable [ERC1155 contract, a multi-token standard.](https://eips.ethereum.org/EIPS/eip-1155)

ERC1155 allows Geode to keep track of multiple Staking Pools. gAVAX is just the artificial name of this set of tokens.

## Understanding ERC1155
Erc1155 is introduced as a better and safer concept than ERC20 and ERC721 tokens. With different "_id" parameters, this contract can store the related data for any token that is fungible or non-fungible.
Fundamentally, there are two things different than ERC20 standard:
1. Balances and approvals relates to **id**
```
// ERC20: 
mapping(address => uint256) private _balances;

// ERC1155: Mapping from token ID to account balances
mapping(uint256 => mapping(address => uint256)) private _balances;
```
2.  Contracts that is not defined as **ERC1155RECEIVER** can't receive.
```
function _doSafeTransferAcceptanceCheck(...) {
if (to.isContract()) {
	try IERC1155Receiver(to).onERC1155Received(...) returns (bytes4 response){
		if (response != IERC1155Receiver.onERC1155Received.selector) {
		revert("ERC1155: ERC1155Receiver rejected tokens");
	}
} catch Error(string memory reason) {
...
} catch {
revert("ERC1155: transfer to non ERC1155Receiver implementer");
}}}
```
3. Note that: There is no id specific operator approvals
```
//ERC20: Mapping from account to allowances
mapping(address => mapping(address => uint256)) private _allowances;

//ERC1155: Mapping from account to operator approvals
mapping(address => mapping(address => bool)) private _operatorApprovals;
```
> Further reading: https://docs.openzeppelin.com/contracts/3.x/erc1155

# gAVAX, built different
gAVAX relies on the ERC1155 implementation and as it can be seen in the tests, it provides the fundamental functionality. However, it is built with some additional implementations to allow wider range of interactions.

> We will mention the additional parts that ensures scalability, while explaining the desired core functionalities of gAVAX.
 
 ### gAVAX is a Database of "Balances" and "Prices" with extra "Scalability"

## Balances
wETH2 acts as a **Database** of the amount of Staked Ether that is represented by multiple Representatives.

Balances for the depositors of a single type of wETH2, are tracked with a predetermined ID. IDs are the main separators of different types of wETH2, thus different representatives.

## Prices
The balance of users, that is stored in __balances_ parameter of the wETH2 contract, doesn’t change while the amount of underlying Ether changes, expectedly increasing over time thanks to **Staking Rewards**.

Every different ID of wETH2 has a different __pricePerShare_ value.
```
// shows the underlying ETH for 1 staked ether for given Representative
mapping(uint256 => uint256) private _pricePerShare;
```

### **_pricePerShare**
Basically, a variable that represents the equivalent of 1 gAVAX in terms of underlying Avax.
__pricePerShare_ is used while minting new tokens through Portal and updated by an Oracle contract with the data coming from ETH2, collected by [Telescope](/o/-MkNl3E-DW6_qNfIAnOQ/s/OYJACYRa4PPsQooN8Wfk/fundamentals/key-components-of-geode-universe#telescope).
```
function setPricePerShare(uint256 pricePerShare_, uint256 _id)external{
	require(hasRole(ORACLE, _msgSender()), "gAVAX: must have ORACLE role to set");
	_pricePerShare[_id] = pricePerShare_;
}
```
> **_pricePerShare** parameter is one of the key components of the support for DeFi.

##  Interfaces : "Scalability"
> **ERC1155 Interfaces** is one of the most important concepts introduced by Geode.fi.

ERC-1155 tokens are not compatible with the DeFi ecosystem, thus they need to be mutated for public usage.

Every wEth2 token has a different use-case, depending on the represented Protocol, therefore it doesn’t come with a preset implementation.

Interfaces are external contracts used to manage the underlying asset(data) for different purposes, allowing Protocols to use the stored data with infinite flexibility!

Notes:
> 1. There can be multiple Interfaces for one Representative's ID.
```
/**
* Mapping from Representative IDs to interface addresses
**/
mapping(uint256 => mapping(address => bool)) private _interfaces;
```
> 2. Only the Representative of given ID can set new Interfaces.
```
function _setInterface(address _Interface,uint256 _id,bool isSet) internal {
	_interfaces[_id][_Interface] = isSet;
}
```

> 3. Transactions that are conducted with Interfaces can bypass the [ERC1155 requirements](https://eips.ethereum.org/EIPS/eip-1155#erc-1155-token-receiver) while other non-compatible contracts can not receive them.
```
function _doSafeTransferAcceptanceCheck(...) private {
	if (to.isContract() && !isInterface(operator, id))
		{...}
}
```

## Case Studies on Interfaces :  ERC20Interface 

Allows 1 specific id to act as an ERC20 token. Important changes on ERC20 implementation

####  ERC20Interface will be using the balance info coming from wETH2, so there is no __balances_

```
    /**
     * @dev Weth2 ERC20 interface doesn't use balance info, catches it from ERC1155.
     * mapping(address => uint256) private _balances;
    **/ 
    function _transfer(...) internal virtual {
        ...
        unchecked {
            _ERC1155.safeTransferFrom(sender,recipient,_id,amount,"0x00");
        }
        ...
    }
```
  
#### There is also a function for _pricePerShare,_ so it is easy for any code to keep track of underlying ETH balance.
```
function pricePerShare() public view returns(uint){
	return _ERC1155.pricePerShare(_id);
}
```
#### Balance info of used ID's ERC20interface will show the wETH2 balance info.
```
function balanceOf(address account) public view virtual override returns (uint256) {
return _ERC1155.balanceOf(account,_id);
}
```
####  TotalSupply info of used ID's ERC20interface will show the wETH2 totalSupply info.
```
    /**
     * @dev Weth2 ERC20 interface doesn't use totalSupply info, catches it from ERC1155.
     * uint256 private _totalSupply;
    **/ 
    function totalSupply() public view virtual override returns (uint256) {
        return _ERC1155.totalSupply(_id);
    }
```

> code: [ERC20INTERFACE](../contracts/Portal/gAvaxInterfaces/ERC20Interface.sol)