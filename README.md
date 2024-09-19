# DCAHQ

This repository contains a Clarity smart contract for a Dollar-Cost Averaging (DCA) manager on the Stacks blockchain.

## Overview

The DCA Manager allows users to set up automated, non-custodial, non-kyc purchases. It supports multiple token pairs, custom intervals, and flexible DCA strategies. Users remain in control and can withdraw at any time .

## Key Features

- Create and manage DCA positions
- Support for multiple token pairs
- Customizable DCA intervals
- Price-based execution conditions
- Fee management system
- Integration with external price oracles and swap strategies

## Main Functions

- `create-dca`: Set up a new DCA position
- `add-to-position`: Add funds to an existing DCA position
- `reduce-position`: Remove funds from a DCA position
- `withdraw`: Withdraw acquired tokens from a DCA position
- `dca-users`: `dca-users-a` (Alex) & `dca-users-b` (Velar). Execute DCA for multiple users

## Configuration

The contract allows for detailed configuration of DCA parameters, including:

- Fee structures (fixed and percentage-based)
- Min/max DCA thresholds
- Slippage protection
- Custom swap strategies

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
