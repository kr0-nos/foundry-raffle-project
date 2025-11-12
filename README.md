# Provably Fair Raffle Smart Contract

A decentralized, trustless raffle system built with Solidity that leverages Chainlink VRF v2.5 for verifiable randomness and Chainlink Automation for automated winner selection.

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Architecture](#architecture)
- [Getting Started](#getting-started)
- [Usage](#usage)
- [Testing](#testing)
- [Deployment](#deployment)
- [Contract Addresses](#contract-addresses)
- [Security Considerations](#security-considerations)
- [License](#license)

## Overview

This project implements a provably fair raffle system where:
- Users can enter by paying an entrance fee
- A winner is automatically selected after a specified time interval
- Random winner selection is guaranteed to be fair using Chainlink VRF
- The entire prize pool is sent to the winner
- The process is fully automated using Chainlink Automation

## Features

### Core Functionality
- **Decentralized Raffle**: Fully on-chain lottery system with no central authority
- **Provably Fair Randomness**: Uses Chainlink VRF v2.5 for cryptographically secure random number generation
- **Automated Execution**: Chainlink Automation triggers winner selection when conditions are met
- **Transparent**: All logic is on-chain and verifiable

### Technical Features
- **Multi-Network Support**: Deployable on Ethereum testnets (Base Sepolia) and local Anvil
- **Comprehensive Testing**: Full unit and integration test suite
- **Gas Optimized**: Uses immutable variables and efficient state management
- **Modular Design**: Clean separation between deployment, configuration, and interaction logic

## Architecture

### Smart Contracts

```
src/
└── Raffle.sol          # Main raffle contract
```

**Key Components:**
- `Raffle.sol`: Core lottery logic with VRF integration
  - Entry management
  - Winner selection via Chainlink VRF
  - Automated upkeep via Chainlink Automation
  - Prize distribution

### Scripts

```
script/
├── DeployRaffle.s.sol      # Main deployment script
├── HelperConfig.s.sol      # Network-specific configurations
└── Interactions.s.sol      # Subscription management scripts
```

### State Variables

```solidity
// Immutable Configuration
uint256 private immutable i_entranceFee;      // Entry cost
uint256 public immutable i_interval;          // Time between drawings
bytes32 private immutable i_keyHash;          // VRF gas lane
uint256 private immutable i_subscriptionId;   // VRF subscription ID
uint32 private immutable i_callbackGasLimit;  // Gas for callback

// Dynamic State
address payable[] private s_players;          // Current participants
uint256 private s_lastTimeStamp;              // Last winner selection time
address private s_recentWinner;               // Most recent winner
RaffleState public s_raffleState;             // OPEN or CALCULATING
```

## Getting Started

### Prerequisites

- [Git](https://git-scm.com/)
- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- [Node.js](https://nodejs.org/) (optional, for additional tooling)

### Installation

1. Clone the repository:
```bash
git clone https://github.com/YOUR_USERNAME/foundry-course-raffle.git
cd foundry-course-raffle
```

2. Install dependencies:
```bash
forge install
```

3. Build the project:
```bash
forge build
```

4. Set up environment variables:
```bash
cp .env.example .env
# Edit .env with your values
```

Required environment variables:
```
PRIVATE_KEY=your_private_key
SEPOLIA_RPC_URL=your_sepolia_rpc_url
ETHERSCAN_API_KEY=your_etherscan_api_key
```

## Usage

### Running Tests

Run all tests:
```bash
forge test
```

Run tests with verbosity:
```bash
forge test -vvv
```

Run specific test:
```bash
forge test --match-test testRaffleStartOpen
```

Run tests with gas report:
```bash
forge test --gas-report
```

### Local Development

1. Start a local Anvil chain:
```bash
anvil
```

2. Deploy to local chain:
```bash
forge script script/DeployRaffle.s.sol --broadcast --rpc-url http://localhost:8545
```

## Testing

The project includes comprehensive test coverage:

### Unit Tests (`test/unit/RaffleTest.t.sol`)

- ✅ Raffle initialization
- ✅ Entry requirements (minimum fee, open state)
- ✅ Player registration
- ✅ Event emissions
- ✅ State transitions (OPEN ↔ CALCULATING)
- ✅ Upkeep conditions
- ✅ Random winner selection
- ✅ Prize distribution
- ✅ Timer reset after winner selection

### Test Coverage

```bash
forge coverage
```

## Deployment

### Deploy to Testnet (Base Sepolia)

1. Ensure your `.env` is configured with:
   - `PRIVATE_KEY`: Your wallet private key
   - `SEPOLIA_RPC_URL`: RPC endpoint
   - `ETHERSCAN_API_KEY`: For verification

2. Deploy:
```bash
forge script script/DeployRaffle.s.sol \
  --rpc-url $SEPOLIA_RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --verify \
  --etherscan-api-key $ETHERSCAN_API_KEY
```

### Post-Deployment Steps

The deployment script automatically:
1. Creates a VRF subscription (if needed)
2. Funds the subscription with LINK
3. Deploys the Raffle contract
4. Adds the Raffle as a consumer to the VRF subscription

### Manual Subscription Management

Create subscription:
```bash
forge script script/Interactions.s.sol:CreateSubscription --broadcast
```

Fund subscription:
```bash
forge script script/Interactions.s.sol:FundSubscription --broadcast
```

Add consumer:
```bash
forge script script/Interactions.s.sol:AddConsumer --broadcast
```

## Contract Addresses

### Base Sepolia
- **VRF Coordinator**: `0x5C210eF41CD1a72de73bF76eC39637bB0d3d7BEE`
- **LINK Token**: `0xE4aB69C077896252FAFBD49EFD26B5D171A32410`
- **Subscription ID**: `XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX`

## How It Works

### 1. Entry Phase
```solidity
function enterRaffle() external payable
```
- Users send ETH (≥ entrance fee) to enter
- Address added to `s_players` array
- Emits `RaffleEntered` event

### 2. Upkeep Check
```solidity
function checkUpkeep() public view returns (bool upkeepNeeded, bytes memory)
```
Chainlink Automation calls this to check if it's time to pick a winner.

Conditions:
- ✅ Time interval has passed
- ✅ Raffle is OPEN
- ✅ Contract has ETH
- ✅ Has players

### 3. Perform Upkeep
```solidity
function performUpkeep(bytes calldata) external
```
When conditions are met:
- Changes state to `CALCULATING`
- Requests random number from Chainlink VRF
- Emits `RequestRaffleWinner` event

### 4. Fulfill Randomness
```solidity
function fulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) internal
```
Chainlink VRF calls this with random number:
- Selects winner: `randomWords[0] % players.length`
- Transfers entire balance to winner
- Resets state to `OPEN`
- Clears `s_players` array
- Updates `s_lastTimeStamp`
- Emits `WinnerPicked` event

## Security Considerations

### Implemented Safeguards

1. **CEI Pattern**: Checks-Effects-Interactions to prevent reentrancy
2. **State Locking**: `CALCULATING` state prevents entries during winner selection
3. **Provable Randomness**: Chainlink VRF ensures fairness
4. **Immutable Configuration**: Critical parameters can't be changed post-deployment
5. **Access Control**: Only VRF Coordinator can call `fulfillRandomWords`

### Known Limitations

- **Entry Fee Not Returned**: Failed entries don't refund gas
- **Winner Selection Delay**: VRF callback takes 1-3 blocks
- **Gas Costs**: Users pay gas for entry transaction

## Gas Optimization

- Uses `immutable` for constant values
- Efficient storage packing
- Minimal SSTORE operations
- Events over storage where possible

## Development Tools

Built with:
- **Solidity 0.8.19**: Smart contract language
- **Foundry**: Development framework
- **Chainlink VRF v2.5**: Verifiable randomness
- **Chainlink Automation**: Automated execution

## Contributing

Contributions are welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Ensure all tests pass
5. Submit a pull request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- [Chainlink](https://chain.link/) for VRF and Automation
- [Foundry](https://getfoundry.sh/) for the development framework
- [Patrick Collins](https://www.youtube.com/@PatrickAlphaC) for educational content

## Contact

For questions or support, please open an issue on GitHub.

---

**⚠️ Disclaimer**: This is an educational project. Use at your own risk. Not audited for production use.
