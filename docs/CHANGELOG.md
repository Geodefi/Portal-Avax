# Changes made since audited contracts

Geode Finance has been audited by omniscia.io while in the process of being built with active research on possible improvements for our liquid staking solution.
[Audit report is here.](https://omniscia.io/geodefi-decentralized-liquid-staking/)
Since the audited version, [which is here](https://github.com/Geodefi/Portal-Avax/tree/dev-audit), there have been significant improvements with a lot of simplifications
on the logical patterns of `StakeUtilsLib`, more gas efficiency on Withdrawal Pool implementation and better, more readible especially code in terms of over complexity of Portal implementation.

This documentation aims to go step-by-step on these changes, while allowing the revisions on our audit to be finalized in a healthy manner.
Firstly we will discuss the changes that made prior to the audit report, then we will go through the changes that are related to audit report.

# Changes that are not related to audit report

[Here is the commits related to changes before audit.] (<https://github.com/Geodefi/Portal-Avax/pull/3>)

## ERC1155 Interfaces

`ERC20Interface.sol` and `ERC20InterfaceRebasing` was deprecated and was not included the Scope of Work for the audit.

## GeodeProxyAdmin.sol

After heavy considerations we went ahead and changed the upgradability pattern of the Portal from `TransparentUpgradability` to `UUPS`. As a result, `GeodeProxyAdmin` contract is deprecated.

## Swap.sol

1. SafeMath is unnecessary for sol >0.8. Thus ,it is being replaced on following contracts:

- `MathUtils`
- `AmplificationUtils`
- `SwapUtils`
- `Swap`

### SwapUtils.sol

2. [Oracle price is being a part of the StableSwap algorithm.](https://github.com/Geodefi/Portal-Avax/pull/7/commits/1e5e407d82db1d7b208bd76da7e401fb432a6621)
3. Debt is a Withdrawal Pool parameter now.
4. [We know there are only two tokens: 0=> Avax, 1=> gAvax](https://github.com/Geodefi/Portal-Avax/pull/7/commits/c8eb206ccca08609d90456163b8805012cb6cab6)
5. [Instead of routing every tx related to idle avax through Portal, we use direct interaction on Swap.sol now](https://github.com/Geodefi/Portal-Avax/pull/7/commits/de7f1062e66c96079384ca161912daf775e1ca26)

## StakeUtils.sol

1. Since we got rid of the routing for idle avax, now we can get rid of the `wrappedAvaxId` logic all together, as well as wrap/unwrap functions.
2. `SLIPPAGE` was a parameter related to debt search, which is not necessary.
3. We can get rid of add/remove liquidity functions which also saves users a lot of gas now.
4. We have a cheap way to enforce buybacks on paydebt and stake functions with debt being implemented on `Swap.sol`.
5. Correct logic for the `reportOracle` is being implemented as well as `sanityCheck()`:

- Oracle now only increases price.
- Oracle can not increase price more than given limit: `DAILY_PRICE_INCREASE_LIMIT`

6. Note that, we will also make `IsOracleActive` not a global but a planet based function.

## Portal

1. Lots of functions deleted as they are not being implemented in `StakeUtils` now: `setSlippage`, `unstake`, etc.
2. params `MAX_PLANET_FEE` and `MAX_OPERATOR_FEE` are deprecated, replaced with `MAX_MAINTAINER_FEE` in the `StakeUtils`.
3. a deactivated operator is given 15 days, this is to make it more easy for planet maintainers to operate their pool (see `deactivatePlanetOperator`)

# Changes made as a response to the Omniscia Audit

[Here is the list of audit related commits.] (<https://github.com/Geodefi/Portal-Avax/pull/3>)
Please read these changes and audit report side by side.

## Vulnerabilities

### Informational & Minor

1. [GUL-01S:](https://github.com/Geodefi/Portal-Avax/pull/3/commits/6f914532ae800dd5405d7e201aa514aba9029026) `changeIdCONTROLLER` sanity check for address(0).
2. [GUL-02S:](https://github.com/Geodefi/Portal-Avax/pull/3/commits/38c24e0af80ddecc15871c6c70b7ee5a7aec0490)
3. [POR-01S:](https://github.com/Geodefi/Portal-Avax/pull/3/commits/f584398415a4990e15e0c8ca909efc129c1652ec) Portal.initialize() sanity check for all parameters are implemented.
4. [SWA-01S:](https://github.com/Geodefi/Portal-Avax/pull/3/commits/74815f8bf1765852baa561839a774f458289d91b) `_gAvax` and `lpTokenTargetAddress` are required to be non-zero address
5. [GUL-01M & GUL-02M:](https://github.com/Geodefi/Portal-Avax/pull/3/commits/7bc717814e4ccad6f55bb2b38ee401198a47340c) `MIN_PROPOSAL_DURATION` is implemented & `MAX_PROPOSAL_DURATION`  should be inclusive.
6. [AVA-02M:](https://github.com/Geodefi/Portal-Avax/pull/3/commits/c6d6d5c01cb39284649e75a3ac4b4c1c92f9aa0d) commented statements were not necessary, deleted.
7. [ERC Interfaces](https://github.com/Geodefi/Portal-Avax/pull/3/commits/790c7daae201f318ee3aedf08e5bedf50f3560d2) ERC-01C & ERC-02C & ERC-03C & ERI-01C & ERI-02C & ERI-03C & ERU-01C & ERU-02C . NOTE that ERC and ERI are already deprecated and was not included in SoW.

8. [AVA-01M & AVA-03M:](https://github.com/Geodefi/Portal-Avax/pull/3/commits/8a67bfe9856c270a33f3358bccfa89c72be36312) finding indicates adjustments performed to the original `EIP-1155` implementation. With its final form, only difference between `ERC1155SupplyMinterPauser` and Openzeppelin's implementation is `doSafeTransferAcceptanceCheck` is being virtual: <https://www.diffchecker.com/W9Am9Owk>

9. [GPA-02M & GPA-01C:](https://github.com/Geodefi/Portal-Avax/pull/3/commits/65eeebee93f8fbdf9a051c8c78990be64fe77118)
GPA is being deprecated as `UUPS` is being used now.

10. [GUL-02S:](https://github.com/Geodefi/Portal-Avax/pull/3/commits/38c24e0af80ddecc15871c6c70b7ee5a7aec0490)

11. SUL-04M:& SUL-05M: related functions are deleted or fixed already.

### Medium

1. POR-02M: `fee` is a shared parameter because Planets(type 5) inherit operators (type 4), with additional properties. `fee` is inherited.

2. [SUL-03M:](https://github.com/Geodefi/Portal-Avax/pull/3/commits/8dc0b2c995f2086710af0ea2eb8916900660deb4) instead of a require check, fee is set to remaining `surplus` if it is lower than `surplus` of the pool.

### Major

1. [SUL-01M:](https://github.com/Geodefi/Portal-Avax/pull/3/commits/86c573a6c85b7c92519a7d273844256a24f5b653)
 `onlyGovernance` check from Portal is being replaced with maintainer check in the `StakeUtils`. This approach will be later finalized to `OnlyMaintainer` modifier in Portal.
2. [SUL-02M:](https://github.com/Geodefi/Portal-Avax/pull/3/commits/55f5012358fb58c8b09109433411aa7ef5703a87)
 `deployWithdrawalPool` _now_ checks if there is already a Withdrawal Pool to prevent overriding.
3. [GPA01-M:](https://github.com/Geodefi/Portal-Avax/pull/3/commits/65eeebee93f8fbdf9a051c8c78990be64fe77118)
GPA is being deprecated as `UUPS` is being used now.
4. [POR01-M:](https://github.com/Geodefi/Portal-Avax/pull/3/commits/65eeebee93f8fbdf9a051c8c78990be64fe77118) contract size is fixed to 50 with gap of 45 instead of 41.

### Not Addressed

1. DSL-01C: `encodePacked` will be kept as is.
2. SUL-01C: return statement will be kept as is.
2. SUL-02C: Function is deleted.

## Notes

1. [All contracts are now fixed to =0.8.7](https://github.com/Geodefi/Portal-Avax/pull/3/commits/18661165907c7b46ff99fbe4281b5f2a8b37344d)

2. key naming for `DataStore`:

- `CONTROLLER` is uppercase since it is very important. While it is not consistent with the rest of the camelCase keys, it is consistent wherever it is mentioned.

3. Initial SoW did not include the `ERC20Interfaces` except `ERC20InterfaceUpgradable.sol`: `ERC20Interfaces.sol` and `ERC20InterfacesRebasing.sol`

4. **[SUS-01M](https://omniscia.io/geodefi-decentralized-liquid-staking/manual-review/SwapUtils-SUS#span-idsus-01msus-01m-improper-measurement-of-transferred-amountsspan) needs further assistance!!**

5. Please also edit the audit report according to the changes made related to findings on finalization, if possible.

# Changes made afterwards

1. [pBank logic](https://github.com/Geodefi/Portal-Avax/pull/3/commits/8e9264c7f2ee2b8e5c2376ba42b53a23e236eec6), is a helper logic for the oracle implementation.pBank is the only address on the P subchain that interacts with tokens that is claimed by operator as surplus.
2. [ActivationExpiration moved to StakeUtils](https://github.com/Geodefi/Portal-Avax/pull/5)
3. `DAILY_PRICE_INCREASE_LIMIT` changed to `PERIOD_PRICE_INCREASE_LIMIT` because there may be missed days by oracle to update price in a bad scenario, and limit should be calculated accordingly. In such case period limit makes more sense compated to daily limit since oracle period could be something else but not a day at some point. So name change is done and necessary calculations were added.
4. Portal is turned to an ERC1155 holder contract.
5. As a precaution for reentrancy, token burn is taken before the token transfer which was after the token transfer beforehand.
6. `WithdrawAdminFees` function made nonReentrant in case of reentrancy.
7. `onlyMaintainer` moved to StakeUtilsLib from Portal.
8. `IGNORABLE_DEBT` is increased from `1e10` to `1e15` and than to `1 ether` as a lower limit for the buybacks at `stake` and `payDebt` functions.
9. Debt calculation is improved by considering `swapFee` during calculations.
10. `planetDebt` and `payDebt` functions are fixed and improved by considering `unclaimedFees` of the planet, during calculations.
