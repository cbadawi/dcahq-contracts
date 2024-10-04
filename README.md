# DCAHQ

This repository contains a Clarity smart contract for a Dollar-Cost Averaging (DCA) manager on the Stacks blockchain.

## Overview

This repository contains Clarity smart contracts that implement a decentralized Dollar-Cost Averaging (DCA) protocol on the Stacks blockchain. The DCA Manager is the main entry point and allows users to set up automated, non-custodial, amm-agnostic, non-kyc purchases. It supports multiple token pairs (referenced as a `source` and a `target`), custom intervals, and flexible DCA strategies. Users remain in control and can withdraw at any time .

The contracts make use of the following external contracts and traits:

- Token Traits:
  2 traits were needed as tokens were not compatible.
  - ft-trait-a: SIP-010 trait for the ALEX fungible tokens.
  - ft-trait-b: SIP-010 trait for the VELAR fungible tokens.
- AMM Contracts:
  - Alex and Velar AMMs for executing swaps.
- Authorization Contract:
  - auth: Manages administrative permissions.
- Vault:
  - Contains all tokens and handles the pausing & transfer of tokens using the `transfer-ft` function.
- Strategy Trait:
  - Defines the interface for swap strategies.
- Startegy Contract:
  - Implements the strategy trait. Transfers the source token to itself, swaps it depending on the token-pair AMM and returns the resulted target token to the vault.

### Key Features

- Create and manage DCA positions
- Support for multiple token pairs. Possible to support both Velar and Alex token pairs. Planning to roll out all pairs gradually.
- Customizable DCA intervals. Choose between automatic purchases every 2 hours, day or week.
- Price-based execution conditions.
- Fee management system.
- Choose from approved strategies. Currently only the default constant strategy is enabled. More custom strategies will be added in the future.

### Main Functions

- `create-dca`: Set up a new DCA position
- `add-to-position`: Add an amount of the `source` token to an existing DCA position
- `reduce-position`: Remove an amount of the `source` token from a DCA position
- `withdraw`: Withdraw `target` token acquired tokens from a DCA position
- `dca-users`: `dca-users-a` (Alex) & `dca-users-b` (Velar). Execute DCA for multiple users. Initially, only approved users can call this function to minimize the risk of intentional slippage. In future versions, a decentralized network will take over this role.

### Configuration

The contract allows for detailed configuration of DCA parameters, including:

- Fee structures (fixed and percentage-based relative to the `source` token)
- Min/max DCA thresholds
- Pausing the DCA.
- Slippage protection
- Custom swap strategies

## Usage

### Initial configuration

```
(add-approved-contract contract-owner)
(add-approved-contract dca-manager)
(set-approved-strategy default-strategy-contract) ;; only approved principals can add a strategy.
(set-sources-targets-config source target id fee-fixed fee-percent source-factor helper-factor is-source-numerator min-dca-threshold max-dca-threshold max-slippage token0 token1 token-in token-out)
```

- Since dca-manager is (tries to be) amm-agnostic, the source-target-config should contain every configuration needed to run the dca on both Alex and Velar AMMs. For example the `source-factor helper-factor` are parameters passed to the alex swap function while `token0 token1 token-in token-out` are passed to Velar.

- `set-sources-targets-config` should be called for every source-target pair.

### Create DCA Positions

```
(create-dca source-trait target interval total-amount dca-amount min-price max-price strategy)
```

Called by the users. A user position is defined by an address, source, target, interval and a strategy. A user can have any number of positions, but not 2 positions with these same keys above. For example

This function call transfers the designated amount of source token to the `dca-vaut` contract
Parameters:

- source-trait: The token the user wants to swap from.
- target: The token the user wants to swap to.
- interval: The time interval between swaps. Accepts u0, u1, u2 for 2 hours, daily and weekly respectively. Maps to seconds using `define-map interval-id-to-seconds`.
- total-amount: The total amount of the source token allocated for the DCA position.
- dca-amount: The amount of the source token to swap at each interval.
- min-price: Minimum acceptable price.
- max-price: Maximum acceptable price.
- strategy: The swap strategy to use.

### Managing DCA Positions

While having an active DCA position, a user can modify the dca-data map which is the source of truth that defines a position's balance, status etc. The user has these options to manage his positions :

#### Add to Position:

Increase the total source amount of an existing DCA position.

`(add-to-position source-trait target interval strategy amount)`

#### Reduce Position:

Decrease the total source amount of an existing DCA position.

`(reduce-position source-trait target interval strategy amount)`

#### Withdraw:

Withdraw accumulated target tokens from a DCA position.

`(withdraw source target-trait interval strategy amount)`

#### Update DCA Data:

Modify parameters like pause status, amount per purcahse, and price thresholds.

`(set-user-dca-data source target interval strategy is-paused amount min-price max-price)`

### DCA

The `dca-users-a` and `dca-users-b` automate the processing of DCA positions for multiple users by executing token swaps through different Automated Market Makers (AMMs).
They are almost identical except that :

- dca-users-a: Executes swaps using the Alex AMM.
- dca-users-b: Executes swaps using the Velar AMM.

They process multiple user DCA positions by aggregating their swap amounts and executing a bulk swap through the Alex AMM. This approach optimizes gas fees and ensures efficient execution of swaps.

Built to be fault tolerant. If one user's validation fails, the function will continue processing the rest of the users without updating the faulty user's dca-data map.

Important Parametere:

- keys: A list of up to 50 user DCA keys. A kew is a tuple that defines a DCA Position. Where each key contains:
  - source: Source token principal (token to swap from).
  - user: User's principal address.
  - target: Target token principal (token to swap to).
  - interval: DCA interval ID.
  - strategy: Strategy contract principal.

### Function Flow of dca-users-a & dca-users-b

- Authorization & strategy checks
- `dca-user-a` & `dca-user-b`
  Notice the subtle name difference in `user`. These functions map through the keys list to perform various checks and returnns the amount, if any, a user should trade.
  - Key checks. Invalid keys exit the current function and return an error but doesnt crash the entire flow.
  - Amount checks. Capped at the amound allowed by the user
  - Timestamp checks. Attempts to run trades before their set interval time passes since their last trade exit the current function and return an error but doesnt crash the entire flow.
  - Price checks. Ignore the trade when the price is outside of the optional boundary set by the user. The method to fetch the price of each pair is fetched depending on which AMM it resides.
- `aggregate-amounts` adds the amounts fetched by dca-user map and returns the total source amount to swap and the fee amount.
- Slippage check with `min-dy`
- Transfers the source token from the vault to the strategy contract
- Calls the appropriate stratetgy function depedning on which amm the pair belongs to.
  - The strategy contract does the swap and returns the target amount to the vault.
- The dca manager adds the fee to trasury and adds the target amount each user now has to the dca-data map. The target amount is calculated on a pro-rata basis : (total target amount swapped) \* (user's source amount calculated in dca-user) / (total source amount) .

## tests

Some manual work is needed to run tests. I need to add some initializations to the Alex and Velar project requirements to remove the manual setup.

```toml
[[project.requirements]]
contract_id = 'SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.amm-pool-v2-01'
etc...
```

For now I manually replace the hardcoded velar and alex function calls (`'SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.amm-pool-v2-01` & `'SP1Y5YSTAHZ88XYK1VPDH24GY0HPX5J4JECTMY4A1.univ2-core`) [dca manager](contracts/dca-manager.clar) & [default strategy](contracts/default-strategy.clar) with the mock-alex and mock-velar contracts.

```bash
npm test dca-manager
```
