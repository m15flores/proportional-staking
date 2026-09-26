# Proportional Staking

Extended version of the Staking App exercise from the Blockchain Accelerator program (Module 2), rebuilt as a multi-user staking pool with proportional, continuous reward accrual, instead of a single fixed-amount staker earning a flat per-period reward.

Original exercise: [staking-app](https://github.com/m15flores/blockchain-accelerator-journal/tree/main/module-2/staking-app)

## What changed vs. the original exercise

The original `StakingApp.sol` supported exactly one staked amount per user (`fixedStakingAmount`), paid a flat ETH reward per fixed period, and required the owner to manually fund the contract with ETH via a restricted `receive()`.

This version is a different design, built around the reward-accounting pattern popularized by SushiSwap's `MasterChef` contract:

- Any number of users can stake **any amount** of `stakingToken`, at any time
- Rewards accrue **continuously**, tracked via a global accumulator (`accRewardPerShare`) and a per-user snapshot (`rewardDebt`), not in fixed, all-or-nothing periods
- Rewards are paid in a separate `RewardToken`, not the staking token itself or native ETH
- `stake`, `unstake`, and `claimRewards` all settle any pending reward automatically before changing a user's position

The original exercise is kept unchanged in the journal repo as a reference point; this repo is a separate, extended version rather than an in-place rewrite.

## How rewards are calculated

Each time `stake`, `unstake`, or `claimRewards` is called, the contract:

1. Updates `accRewardPerShare` based on time elapsed since the last update and the current `totalStaked`
2. Computes the caller's pending reward as `(userAmount * accRewardPerShare / PRECISION) - userRewardDebt`
3. Pays out that pending amount before touching the user's stake
4. Resets `rewardDebt` to the user's new position

This means a user who stakes after rewards have already started accruing never receives rewards generated before they joined the pool. Each user's `rewardDebt` snapshot ensures that.

## Contracts

- `MockToken.sol` : generic ERC-20 used as the staking token in tests
- `RewardToken.sol` : standard ERC-20 (OpenZeppelin), fixed supply minted to deployer, used to pay staking rewards
- `ProportionalStaking.sol` : multi-user staking pool with proportional, continuous reward accrual

## Testing

Built with Foundry. 18 tests across four levels : basic single-user actions, time-based reward accrual (`vm.warp`), multi-user proportional distribution, and repeated-action edge cases, plus fuzz tests on `stake` and `unstake` with randomized amounts.

​```bash
forge test -vv
​```

100% coverage (lines, statements, branches, functions) across both contracts:

​```bash
forge coverage
​```

| File                         | % Lines          | % Statements     | % Branches      | % Funcs        |
|------------------------------|-------------------|-------------------|-------------------|-----------------|
| src/ProportionalStaking.sol  | 100.00% (46/46)   | 100.00% (44/44)   | 100.00% (10/10)   | 100.00% (6/6)   |
| src/RewardToken.sol          | 100.00% (2/2)     | 100.00% (1/1)     | 100.00% (0/0)     | 100.00% (1/1)   |

## Notes

The token address is cast to `IERC20` once in the constructor and stored as `immutable`, rather than stored as a raw `address` and cast on every call. This gives compile-time protection against the token address changing after deployment, and avoids repeating the cast across every function that touches
the token. All token transfers use `SafeERC20`, which reverts on failure instead of relying on unchecked return values. Both patterns were first established in [cryptobank-erc20](https://github.com/m15flores/cryptobank-erc20).

Rewards are paid in a separate `RewardToken` rather than the staking token itself. `stakingToken` is principal, custodied, and never spent by the contract. `RewardToken` is the incentive, minted/funded separately and only ever paid out, never received from users.

Unlike the original exercise, where rewards were paid in fixed, all-or-nothing periods (waiting 3x the staking period without claiming still only paid out 1x the reward), `accRewardPerShare` accrues continuously, second by second. A user who waits longer between claims simply accumulates more
pending reward proportional to the time elapsed; nothing is lost by claiming early or late.