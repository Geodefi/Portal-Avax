# Understanding Portal.sol

Portal is the main contract of the Geode Finance that gathers multiple revolutionary implementation related to liquid staking and further decentralization under a single roof:

1. Creation of **Multiple** Liquid Staking synthetic assets.
2. Automated management of underlying funds for these assets.
3. Price pegging mechanisms for these assets via Withdrawal Pools implementation.
4. Centralized but Trust-less contracts with Limited Upgradability.
5. Providing an on-chain Oracle for these assets to increase DeFi compatibility.
6. Allowing the usage of dynamic data Structures to ensure future scalability, while maintaining the cost efficiency.

To understand the full scope of the implementation as a contributor, we will go through these Libraries:

1. DataStoreUtils
 - A storage management tool that is specifically designed for multiple users -other contracts- relying on a centralized implementation that is maintained by another protocol -Geode-
 - Most importantly, allowing secure contract upgrades while ensuring backwards compatibility.
2. GeodeUtils
 - Ensuring the security of centralized implementation, Portal, with a hand-shake mechanism that is approved by the users of the contract.
 - In this case, "users" doesn't mean stakers, but "maintainers": other developers who uses the shared logic in their code.
 - Limited Upgradability relies on Senate preventing unwanted changes on the core implementation that can harm the users while upgrading the contracts.
 - To improve your understanding, please refer to [geode white paper.](https://github.com/Geodefi/white_paper/blob/main/geode_whitepaper.pdf) This proposal will be updated & edited in shortly.
3. StakeUtils
 - Implementation of Staking Pools logic that is also combined with Withdrawal Pools, is implemented here.  
 - "Centralized Implementation" & "shared logic" refers to this functionality.
 - To improve your understanding on Withdrawal Pools, please refer to [initial draft for the dynamic withdrawals.](https://docs.google.com/document/d/1ptMrImHonYyXbqAxuhYR0H-LEk07Vaj132SNFoJeCnw/edit?usp=sharing) This proposal will be completed & updated in shortly.

# Let's dive in

We are pretty confident the underlying code is self explanatory thanks to comments, please review the following contracts in order:

## 1. [DataStoreLib](../contracts/Portal/utils/DataStoreLib.sol)

## 2. [GeodeUtilsLib](../contracts/Portal/utils/GeodeUtilsLib.sol)

## 3. [StakeUtilsLib](../contracts/Portal/utils/StakeUtilsLib.sol)

## 4. [Portal](../contracts/Portal/Portal.sol)
