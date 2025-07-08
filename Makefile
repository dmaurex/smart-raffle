-include .env

.PHONY: all test deploy anvil

DEFAULT_ANVIL_KEY := 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
NETWORK_ARGS := --rpc-url http://localhost:8545 --private-key $(DEFAULT_ANVIL_KEY) --broadcast

build :; forge build

test :; forge test

test-sepolia :; forge test --fork-url $(SEPOLIA_RPC_URL) -v

install: # forge has already registered these dependencies and installs them when building
	forge install smartcontractkit/chainlink-brownie-contracts@1.3.0 \
	&& forge install transmissions11/solmate@v6 \
	&& forge install Cyfrin/foundry-devops@0.4.0

anvil :; anvil --steps-tracing --block-time 1

deploy :; @forge script script/DeployRaffle.s.sol:DeployRaffle $(NETWORK_ARGS)

deploy-sepolia:
	@forge script scripts/DeployRaffle.s.sol:DeployRaffle --rpc-url $(SEPOLIA_RPC_URL) \
	--account default --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY) -vvvvv

createSubscription :; @forge script script/Interactions.s.sol:CreateSubscription $(NETWORK_ARGS)

fundSubscription :; @forge script script/Interactions.s.sol:FundSubscription $(NETWORK_ARGS)

addConsumer :; @forge script script/Interactions.s.sol:AddConsumer $(NETWORK_ARGS)

snapshot :; forge snapshot

format :; forge fmt

clean  :; forge clean
