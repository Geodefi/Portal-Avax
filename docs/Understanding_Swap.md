# Understanding Swap.sol
Swap.sol contains a StableSwap algorithm that is specifically implemented for multiple id's of one ERC1155 token. Swap.sol is a fork of Saddle's implementation.

###  StableSwap Algorithms
Basically, please refer to the following sources if you are not familiar with these concepts:
1. [Liqudity Pools](https://xord.com/research/curve-stableswap-a-comprehensive-mathematical-guide/)
2. [stableswap-paper](https://curve.fi/files/stableswap-paper.pdf)  
3. [Saddle's docs on SS](https://xord.com/research/curve-stableswap-a-comprehensive-mathematical-guide/)

## SwapUtils.sol
SwapUtils Library is designed to create the StableSwap algorithms functionalities. In this documentation we will only mention the changes made to the contract for simplicity

### Instead of multiple ERC20 tokens: multiple IDs from one ERC1155 token:
```
Added Line70:
    // wETH2 contract reference indexes for all tokens being pooled
    uint256[] pooledTokenIndexes;
    // wETH2 contract reference
    IgAVAX referenceForPooledTokens; 
    
function swap:
function addLiquidity:
function removeLiquidity: 
function removeLiquidityOneToken: 
function withdrawAdminFees:
function removeLiquidityImbalance:
	// IERC20 token = pooledTokens[i]; ** is simply changed to: **
		IgAVAX wETH2Reference = self.referenceForPooledTokens;
	// For Example:
	Old:
		uint256 balance = token.balanceOf(address(this)).sub(self.balances[i]);
	 New:
		uint256 tokenBalance = wETH2Reference.balanceOf(address(this),self.pooledTokenId) - self.balances[1];
```

### Calculations related the token multipliers are not needed:
```
Commented Line78:
	//token multipliers are not needed as such every pool will have one gAVAX token & and id 1.
	//uint256[] tokenPrecisionMultipliers;

function _xp(Swap storage self):
function _xp(uint256[] memory balances):
	// these functions are commented and will not be used.


function calculateWithdrawOneTokenDY:
function getVirtualPrice:
function _calculateSwap:
function calculateTokenAmount:
function removeLiquidityImbalance:
function addLiquidity:
	// We are not using xp as it only loops thorough multipliers. We will use self.balances instead of xp here.
``` 

### ! NOTE : Calculations related the price is needed, to allow higher A. 
To be able to implement a yield bearing stable asset to StableSwap algorithm, we should include the price of the underlying asset to the calculation. By that, the implementation can handle higher A parameters while still allowing the 1:1 pricing.
> This is currently a known issue and under development 

> For this change to be secure,  it is crucial for Price Oracle to be trustless.

# * A future questionnaire
## What will happen when gAVAX price increases over time because of the staking rewards ?
 
> Special thanks to [@halo3mic](https://github.com/halo3mic) for conducting following experiments on the Withdrawal Pools.

Below are two different StableSwap pools with A=60 and A=1000 depicting the effect of slippage on trades. When slippage is low the traders lose money, but it is easy for oracle to influence pools price and keep it to the peg - and the opposite when slippage is high.

The problem is the need to follow the oracle price due to using 1:1 (pegged) pools for two unpegged assets. As the value of gAVAX/AVAX increases over time StableSwap math still incentivises trading 1:1 despite price increase. 
Thus it would be worth exploring unpegged pools (incentivise the same value instead of the number of tokens) - [Vyper implementation](https://github.com/curvefi/curve-crypto-contract/blob/master/contracts/tricrypto/CurveCryptoSwap.vy). 

Then A could be set much higher eg. 1000.

## A=60; liquidity=2e6; fee=4bps

Need 18299 token surplus for daily price increase of 0.0247% 

### Balanced pool: `1:1`

| amountIn | slippage | price | *daysLost |
| --- | --- | --- | --- |
| 1 | 0% | 0.9995 | 0 |
| 10000 | 0.01% | 0.9994 | 0 |
| 50000 | 0.08% | 0.9987 | 3 |
| 300000 | 0.53% | 0.9942 | 21 |
|  |  |  |  |

**daysLost: Days worth of rewards lost due to slippage*

### Slightly Unbalanced pool:`9:11`

| amountIn | slippage | price | daysLost |
| --- | --- | --- | --- |
| 1 | 0.33% | 0.9962 | 13 |
| 10000 | 0.35% | 0.9960 | 13 |
| 50000 | 0.42% | 0.9953 | 14 |
| 300000 | 0.96% | 0.9899 | 17 |

### Unbalanced pool: `7:13`

| amountIn | slippage | price | daysLost |
| --- | --- | --- | --- |
| 1 | 1.82% | 0.9813 | 74 |
| 10000 | 1.86% | 0.9810 | 75 |
| 50000 | 2.02% | 0.9793 | 82 |
| 300000 | 3.85% | 0.9610 | 156 |

## A=1000; liquidity=2e6; fee=4bps

Need 277339 token surplus for daily price increase of 0.0247% 

### Balanced pool: `1:1`

| amountIn | slippage | price | daysLost |
| --- | --- | --- | --- |
| 1 | 0% | 0.9995 | 0 |
| 10000 | 0% | 0.9995 | 0 |
| 50000 | 0% | 0.9995 | 0 |
| 300000 | 0.03% | 0.9992 | 1 |

### Slightly Unbalanced pool:`9:11`

| amountIn | slippage | price | daysLost |
| --- | --- | --- | --- |
| 1 | 0.02% | 0.9993 | 1 |
| 10000 | 0.02% | 0.9993 | 1 |
| 50000 | 0.02% | 0.9993 | 1 |
| 300000 | 0.06% | 0.9990 | 2 |

### Unbalanced pool: `7:13`

| amountIn | slippage | price | daysLost |
| --- | --- | --- | --- |
| 1 | 0.11% | 0.9984 | 4 |
| 10000 | 0.11% | 0.9984 | 4 |
| 50000 | 0.12% | 0.9983 | 5 |
| 300000 | 0.25% | 0.9970 | 10 |

---

👉   Code for simulations can be found [here](https://gist.github.com/halo3mic/c2224fe01e8ac3990c153526cb00d2ed)