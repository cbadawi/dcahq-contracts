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
- `dca-users`: Execute DCA for multiple users

## Configuration

The contract allows for detailed configuration of DCA parameters, including:

- Fee structures (fixed and percentage-based)
- Min/max DCA thresholds
- Slippage protection
- Custom swap strategies

## tests

```bash
npm test dca-manager
```
