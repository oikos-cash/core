<p align="center">
  <img src="https://raw.githubusercontent.com/oikos-cash/oikos-assets/refs/heads/master/logo_dark.png" />                                                               
</p>

<h1 align="center">Oikos Protocol</h1>

<p align="center">
  <strong>Next-gen DeFi launchpad</strong>
</p>

<p align="center">
  <a href="https://oikos.cash">Website</a> |
  <a href="https://docs.oikos.cash">Documentation</a> |
  <a href="https://twitter.com/oikos-cash">Twitter</a> |
  <a href="https://discord.gg/Pk6uTsyv3K">Discord</a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Solidity-0.8.23-blue" alt="Solidity"/>
  <img src="https://img.shields.io/badge/License-MIT-green" alt="License"/>
  <img src="https://img.shields.io/badge/Foundry-Latest-orange" alt="Foundry"/>
  <img src="https://img.shields.io/badge/Chain-BSC-yellow" alt="BSC"/>
</p>

---

## Overview

Oikos Protocol is a next-generation DeFi infrastructure that combines **autonomous liquidity management**, **collateralized lending**, and **adaptive token supply** mechanisms built on Uniswap V3. The protocol enables permissionless token launches with built-in liquidity, staking rewards, and borrowing capabilities.

### Key Features

- **Diamond Architecture (EIP-2535)** - Modular, upgradeable smart contract system
- **Autonomous Liquidity Management** - Protocol-owned liquidity on Uniswap V3
- **Collateralized Lending** - Borrow against protocol liquidity with dynamic rates
- **Adaptive Supply Controller** - Algorithmic supply adjustments based on market conditions
- **Staking & Rebasing** - Stake OKS tokens for sOKS with auto-compounding rewards
- **MEV Protection** - TWAP oracle integration for manipulation-resistant pricing
- **Presale Infrastructure** - Fair launch mechanism with soft/hard caps and referral system

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                         OikosFactory                                 │
│  (Vault Deployment, Token Creation, Protocol Configuration)          │
└─────────────────────────────────────────────────────────────────────┘
                                   │
          ┌────────────────────────┼────────────────────────┐
          │                        │                        │
          ▼                        ▼                        ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│  TokenFactory   │    │   ExtFactory    │    │ DeployerFactory │
│  (OKS Token)    │    │ (Vault Facets)  │    │  (Deployers)    │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                   │
                                   ▼
┌─────────────────────────────────────────────────────────────────────┐
│                        Diamond Vault (EIP-2535)                      │
├─────────────────┬─────────────────┬─────────────────┬───────────────┤
│   BaseVault     │  LendingVault   │  StakingVault   │   AuxVault    │
│   (Core Logic)  │  (Borrowing)    │  (Rewards)      │   (Helpers)   │
├─────────────────┼─────────────────┼─────────────────┼───────────────┤
│ ExtVaultShift   │ ExtVaultLending │ExtVaultLiquidat.│  LendingOps   │
│ (Price Shifts)  │  (Loan Mgmt)    │ (Liquidations)  │  (Operations) │
└─────────────────┴─────────────────┴─────────────────┴───────────────┘
                                   │
                                   ▼
┌─────────────────────────────────────────────────────────────────────┐
│                        Uniswap V3 Pool                               │
│              (Protocol-Owned Liquidity Positions)                    │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Deployed Contracts (BSC Mainnet)

### Core Infrastructure

| Contract | Address | Description |
|----------|---------|-------------|
| **OKS Token** | [`0x614da16Af43A8Ad0b9F419Ab78d14D163DEa6488`](https://bscscan.com/address/0x614da16Af43A8Ad0b9F419Ab78d14D163DEa6488) | Protocol governance token |
| **OikosFactory** | [`0x9F5973EC7E5f0781E0fCE71Dd949c997c38508Fc`](https://bscscan.com/address/0x9F5973EC7E5f0781E0fCE71Dd949c997c38508Fc) | Main factory contract |
| **Resolver** | [`0xb9439a0f7d1Ef78d13905574B7ecd87B0Cd52aBE`](https://bscscan.com/address/0xb9439a0f7d1Ef78d13905574B7ecd87B0Cd52aBE) | Address registry |

<!-- ### Satellite Factories

| Contract | Address | Description |
|----------|---------|-------------|
| **ExtFactory** | [`0xd7df8de9780c961fba694ffb2041dcefd58c405a`](https://bscscan.com/address/0xd7df8de9780c961fba694ffb2041dcefd58c405a) | Vault extension facets |
| **TokenFactory** | TBD | Token deployment |
| **PresaleFactory** | [`0x9ff996b0702226cb166be0ac477822dc5387e40e`](https://bscscan.com/address/0x9ff996b0702226cb166be0ac477822dc5387e40e) | Presale contracts |
| **DeployerFactory** | [`0x167b96693e9d274c33e1d72bd9b977cb5c0f16e7`](https://bscscan.com/address/0x167b96693e9d274c33e1d72bd9b977cb5c0f16e7) | Liquidity deployers | -->

---

## Protocol Mechanics

### Vault System

Each vault is a Diamond proxy (EIP-2535) managing:

- **Floor Liquidity** - Concentrated liquidity at price floor 
- **Anchor Liquidity** - Active trading range liquidity
- **Discovery Liquidity** - Liquidity at upper ranges for price discovery
<!-- 
### Lending

Users can borrow reserve assets against protocol liquidity:

```solidity
// Borrow from floor liquidity
vault.borrowFromFloor(borrower, amount, duration);

// Repay loan with fees
vault.repayLoan(borrower);
```

- **Loan Duration**: 30-365 days
- **Dynamic Fees**: Based on protocol parameters
- **Liquidation**: Automatic when loan expires or collateral insufficient

### Staking

Stake OKS to receive sOKS (rebasing staked token):

```solidity
// Stake OKS tokens
staking.stake(amount);

// Unstake and receive OKS + rewards
staking.unstake();
```

- **Epoch-based Rewards**: Distributed per epoch
- **Auto-compounding**: sOKS balance grows via rebasing
- **Lock-in Period**: Configurable epoch lock

### Adaptive Supply

The protocol adjusts token supply based on:

- Time elapsed since last adjustment
- Current spot price vs intrinsic minimum value
- Volatility-adjusted sigmoid function

```solidity
function computeMintAmount(
    uint256 deltaSupply,
    uint256 timeElapsed,
    uint256 spotPrice,
    uint256 imv
) returns (uint256 mintAmount, uint256 sigmoid);
``` -->

---

## Development

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- Node.js >= 18.0.0

### Installation

```bash
# Clone the repository
git clone https://github.com/oikos-cash/core-contracts.git
cd core-contracts

# Install dependencies
forge install

# Build contracts
forge build
```

### Testing

```bash
# Run all tests
forge test

# Run specific test file
forge test --match-path test/Lending.t.sol

# Run with verbosity
forge test -vvvv

# Run invariant tests
forge test --match-contract Invariant

# Gas report
forge test --gas-report
```

### Test Coverage

```bash
forge coverage --report lcov
```

### Deployment

```bash
# Deploy to BSC mainnet
forge script script/deploy/DeployFactory.s.sol:DeployFactory \
  --rpc-url https://bsc-dataseed.binance.org \
  --broadcast \
  --verify
```

---

## Security

### Audits

- QuillAudits - [View Report](./audits/noma_protocol_quillaudits.zip)

### Security Features

- **Reentrancy Guards** - All external calls protected
- **Access Control** - Role-based permissions via modifiers
- **TWAP Oracles** - MEV-resistant price feeds
- **Slippage Protection** - Configurable deviation thresholds
- **Emergency Functions** - Protocol pause capabilities

### Bug Bounty

For responsible disclosure of security vulnerabilities, please contact: security@oikos.cash

---

## Contract Verification

All contracts are verified on BscScan. Source code matches deployed bytecode.

```bash
# Verify a contract
forge verify-contract <ADDRESS> src/path/Contract.sol:Contract \
  --chain 56 \
  --etherscan-api-key <API_KEY>
```

---

## Configuration

### Protocol Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `loanFee` | Daily loan fee (basis points) | 57 (0.057%) |
| `twapPeriod` | TWAP lookback period | 120s |
| `maxTwapDeviation` | Max price deviation (ticks) | 200 (~2%) |
| `minDuration` | Min presale duration | 3 days |
| `maxDuration` | Max presale duration | 90 days |

---

## Integration

### Reading Vault Data

```solidity
interface IVault {
    function pool() external view returns (IUniswapV3Pool);
    function getFloorLiquidity() external view returns (uint256);
    function getCeilingLiquidity() external view returns (uint256);
    function getOutstandingLoans() external view returns (uint256);
}
```

### Interacting with Factory

```solidity
interface IOikosFactory {
    function deployVault(VaultDeployParams memory params) external returns (address);
    function getVaultFromPool(address pool) external view returns (address);
    function getProtocolParameters() external view returns (ProtocolParameters memory);
}
```

---

## Project Structure

```
├── src/
│   ├── bootstrap/          # Presale contracts
│   ├── controllers/        # Supply & dividends controllers
│   ├── errors/             # Custom error definitions
│   ├── factory/            # Factory contracts
│   ├── interfaces/         # Contract interfaces
│   ├── libraries/          # Shared libraries
│   ├── model/              # Pricing models
│   ├── staking/            # Staking contracts
│   ├── token/              # OKS token implementations
│   ├── types/              # Type definitions
│   └── vault/              # Vault facets & upgrades
├── script/                 # Deployment & operation scripts
├── test/                   # Test suite
└── lib/                    # External dependencies
```

---

## Dependencies

- [OpenZeppelin Contracts](https://github.com/OpenZeppelin/openzeppelin-contracts) - Security primitives
- [OpenZeppelin Upgradeable](https://github.com/OpenZeppelin/openzeppelin-contracts-upgradeable) - Proxy patterns
- [Uniswap V3 Core](https://github.com/Uniswap/v3-core) - AMM integration
- [Uniswap V3 Periphery](https://github.com/Uniswap/v3-periphery) - Helper contracts
- [Solmate](https://github.com/transmissions11/solmate) - Gas-optimized primitives
- [Forge Std](https://github.com/foundry-rs/forge-std) - Testing utilities

---

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## Contributing

We welcome contributions! Please see our [Contributing Guidelines](CONTRIBUTING.md) for details.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

---

## Links

- **Website**: [https://oikos.cash](https://oikos.cash)
- **Documentation**: [https://docs.oikos.cash](https://docs.oikos.cash)
- **Twitter**: [@oikoscash](https://twitter.com/oikoscash)
- **Discord**: [discord.gg/oikos](https://discord.gg/Pk6uTsyv3K)
- **GitHub**: [github.com/oikos-cash](https://github.com/oikos-cash)

---

<p align="center">
  <sub>Built with love by the Oikos team</sub>
</p>
