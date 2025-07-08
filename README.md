
# 🎰 Smart Raffle

A decentralized, transparent, and fair raffle system built in Solidity, powered by Chainlink VRF v2.5 and Chainlink Automation. This project showcases a smart contract project with randomness integration, automation, deployment, and testing using Foundry.


### Credit 🙏
This project is part of a code-along based on the [Foundry Fundamentals](https://updraft.cyfrin.io/courses/foundry) course by [Cyfrin](https://cyfrin.io/). Big thanks for Patrick Collins and his team for providing free web3 education.

---

## ✨ Features

- **Chainlink VRF v2.5**: Verifiable randomness ensures fairness in winner selection.
- **Chainlink Automation**: Raffle execution and upkeep without manual intervention.
- **Efficient Solidity Patterns**: Optimized error handling, state updates, and storage management.
- **Multiple Entry Support**: Players can enter more than once to increase their odds.
- **Foundry-based Workflow**: Lightning-fast testing, scripting, and deployment.
- **Modular DevOps**: Easily add configurations to deploy on other blockchains.

---

## 📚 Tech Stack

| Tool            | Purpose                                     |
|-----------------|---------------------------------------------|
| Solidity        | Smart contract language                     |
| Foundry         | Compilation, testing, scripting             |
| Chainlink VRF & Automation | Randomness & cron-style triggers |
| Sepolia Testnet | Live test environment                       |
| Makefile        | Streamlined local commands                  |

---

## 🚀 Getting Started
Follow these steps to clone, install, and test the project locally or on Ethereum Sepolia testnet.

### 1. Prerequisites 🧰
You need to have Git and Foundry installed. Then clone the repository.

```shell
$ git clone https://github.com/dmaurex/smart-raffle.git
$ cd smart-raffle
```

### 2. Environment Setup 🔐
To run tests or deploy on Ethereum Sepolia testnet, create a `.env` file and set the following variables:
```
SEPOLIA_RPC_URL=...
ETHERSCAN_API_KEY=...
```

### 3. Building 🛠️
Install dependencies and build the contracts:

```shell
$ make build
```

### 4. Run Tests 📝
Run tests locally:

```shell
$ make test
# Or run a specific test
$ forge test --mt <specific-test> -vvvvv
```

Run fork tests on Sepolia Ethereum testnet:

```shell
$ make test-sepolia
```


## 🌐 Deployment
The provided scripts allow for an easy deployment of the raffle contract. Live deployments require additionally setting up Chainlink VRF & Automation.

### Local deployment on an anvil chain 🚧
The local setup will automatically create and fund a mock Chainlink VRF subscription for you. Simply start a local anvil chain and deploy your contract:

```shell
$ make anvil
$ make deploy
```

### Deployment Sepolia testnet 🛰️
To deploy to Ethereum Sepolia with live Chainlink VRF & Automation follow these steps:
1. Go to [Chainlink VRF Subscription UI](https://vrf.chain.link/sepolia/new), create a new subscription, and fund it with testnet LINK.
2. Open `script/HelperConfig.s.sol` and update the `getSepoliaEthConfig()` function with our configuration:

```solidity
    entranceFee: 0.01 ether,    // <-- Specify the raffle entrance fee
    interval: 30,               // <-- Specify the duration of a raffle round in seconds
    subscriptionId: 0,          // <-- Replace with your subscription ID
    account: DEFAULT_SENDER     // <-- Replace with your wallet address
```

3. Run the following command, which deploys the `src/Raffle.sol` smart contract and adds it as consumer to your subscription.

```shell
$ make deploy-sepolia
```

5. Use [Chainlink Automation](https://automation.chain.link/) to schedule upkeep calls that trigger the winner selection.


## 🎟️ Usage
Once the raffle contract is deployed and Chainlink VRF & Automation are live, players can enter the raffle:

```shell
$ cast send <RAFFLE_CONTRACT_ADDRESS> "enterRaffle()" \
  --value 0.1ether \
  --private-key <PRIVATE_KEY> \
  --rpc-url $SEPOLIA_RPC_URL
```

---

## 📂 Project Structure
The repository follows the usual Foundry folder structure:
```bash
.
├── lib/
├── script/
│   ├── DeployRaffle.s.sol — "Deployment script"
│   ├── HelperConfig.s.sol — "Network configurations for different chains"
│   └── Interactions.s.sol — "Scripts for creating/funding a subscription and adding a consumer" 
├── src/
│   └── Raffle.sol — "Core smart contract"
├── test/
│   ├── integration/
│   ├── mocks/
│   └── unit/
…       └── RaffleTest.t.sol — "Unit and fork tests"
```

## 🤝 Contributions
While this project is a personal learning showcase, feedback and collaboration are always welcome! You should also checkout the original repository by Cyfrin: [foundry-smart-contract-lottery-cu](https://github.com/Cyfrin/foundry-smart-contract-lottery-cu).


## 📜 License
This project is licensed under the **GNU General Public License v3.0**.

It is derivative work based on the educational project [foundry-full-course-cu](https://github.com/Cyfrin/foundry-full-course-cu) by Cyfrin, and follows the same open-source licensing conditions.
See the [LICENSE](./LICENSE) file for more details.
