// SPDX-License-Identifier: SEE LICENSE IN LICENSE

/*
    This file is part of a code-along project based on the Foundry Fundamentals course by Cyfrin
    found at https://updraft.cyfrin.io/courses/foundry.
    This project is derivative work and licensed under the same GNU General Public License v3.0.
    You may obtain a copy of the License at https://www.gnu.org/licenses/gpl-3.0.html
*/

pragma solidity 0.8.30;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

/**
 * @title Raffle
 * @author dmaurex
 * @notice Smart contract to implement a transparent and fair raffle
 * @dev Uses ChainLink VRFv2.5 and Automation
 */
contract Raffle is VRFConsumerBaseV2Plus {
    /* Errors */
    error Raffle__NotEnoughEthToEnterRaffle();
    error Raffle__TransferFailed();
    error Raffle__RaffleNotOpen();
    error Raffle__UpkeepNotNeeded(uint256 balance, uint256 playersLength, uint256 raffleState);

    /* Type declarations */
    enum RaffleState {
        OPEN, // = 0
        CALCULATING // = 1

    }

    /* State variables */
    uint32 private constant NUM_WORDS = 1;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint256 private immutable i_entranceFee;
    uint256 private immutable i_interval;
    bytes32 private immutable i_keyHash; // gas lane
    uint256 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;
    address payable[] private s_players; // no mapping -> players can enter multiple times
    uint256 private s_lastTimeStamp;
    address private s_recentWinner;
    RaffleState private s_raffleState;

    event RaffleEntered(address indexed player);
    event WinnerPicked(address indexed winner);
    event RequestedRaffleWinner(uint256 indexed requestId);

    constructor(
        uint256 entranceFee,
        uint256 interval,
        address vrfCoordinator,
        bytes32 keyHash,
        uint256 subscriptionId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2Plus(vrfCoordinator) {
        i_entranceFee = entranceFee;
        i_interval = interval;
        s_lastTimeStamp = block.timestamp;
        i_keyHash = keyHash;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
        s_raffleState = RaffleState.OPEN;
    }

    // Enter the raffle
    function enterRaffle() external payable {
        // require(msg.value >= i_entranceFee, "Not enough ETH sent!"); // low gas efficiency
        // require(msg.value >= i_entranceFee, NotEnoughEthToEnterRaffle()); // specific compiler version and still low gas efficiency
        if (msg.value < i_entranceFee) {
            // best gas efficiency
            revert Raffle__NotEnoughEthToEnterRaffle();
        }

        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle__RaffleNotOpen();
        }

        // TODO: prevent double entering?

        s_players.push(payable(msg.sender));
        emit RaffleEntered(msg.sender); // emit event because storage (s_players) was updated
    }

    /**
     * @dev This is the function that the Chainlink nodes will call to see
     * if the raffle is ready to have a winner picked.
     * The following should be true in order for upkeepNeeded to be true:
     * 1. The time interval has passed between raffle runs
     * 2. The lottery is open
     * 3. The contract has ETH
     * 4. Implicitly, you subscription has LINK
     * @param - ignored
     * @return upkeepNeeded - true if it's time to restart the raffle
     * @return - ignored
     */
    function checkUpkeep(bytes memory /* checkData */ )
        public
        view
        returns (bool upkeepNeeded, bytes memory /* performData */ )
    {
        bool timeHasPassed = ((block.timestamp - s_lastTimeStamp) >= i_interval);
        bool isOpen = s_raffleState == RaffleState.OPEN;
        bool hasBalance = address(this).balance > 0;
        bool hasPlayers = s_players.length > 0;
        upkeepNeeded = timeHasPassed && isOpen && hasBalance && hasPlayers;
        return (upkeepNeeded, "");
    }

    // Request a random number and set state to calculating
    function performUpkeep(bytes calldata /* performData */ ) external {
        // Check if enough time has passed
        (bool upkeepNeeded,) = checkUpkeep("");
        if (!upkeepNeeded) {
            revert Raffle__UpkeepNotNeeded(address(this).balance, s_players.length, uint256(s_raffleState));
        }
        s_raffleState = RaffleState.CALCULATING; // TODO: emit event?
        // Make request for random number
        uint256 requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: i_keyHash,
                subId: i_subscriptionId,
                requestConfirmations: REQUEST_CONFIRMATIONS,
                callbackGasLimit: i_callbackGasLimit,
                numWords: NUM_WORDS,
                // Set nativePayment to true to pay for VRF requests with Sepolia ETH instead of LINK
                extraArgs: VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({nativePayment: false})) // TODO: set to true?
            })
        );
        // Actually redundant because vrfCoordinator will also emit an event with the requestId
        // but doing it here simplifies testing
        emit RequestedRaffleWinner(requestId);
    }

    // Callback VRF function that picks a winner and transfers the prize
    function fulfillRandomWords(uint256, /* requestId */ uint256[] calldata randomWords) internal override {
        // Checks...

        // Effects (Internal Contract State)
        uint256 winnerIdx = randomWords[0] % s_players.length;
        s_recentWinner = s_players[winnerIdx];
        s_raffleState = RaffleState.OPEN;
        s_players = new address payable[](0);
        s_lastTimeStamp = block.timestamp;
        emit WinnerPicked(s_recentWinner); // place events before Interactions!

        // Interactions (with External Contracts)
        (bool success,) = s_recentWinner.call{value: address(this).balance}("");
        if (!success) {
            revert Raffle__TransferFailed();
        }
    }

    /* Getter functions */

    function getRaffleState() external view returns (RaffleState) {
        return s_raffleState;
    }

    function getPlayer(uint256 playerIdx) external view returns (address) {
        return s_players[playerIdx];
    }

    function getLastTimeStamp() external view returns (uint256) {
        return s_lastTimeStamp;
    }

    function getRecentWinner() external view returns (address) {
        return s_recentWinner;
    }
}

// Layout of the contract file:
// version
// imports
// errors
// interfaces, libraries, contract

// Inside Contract:
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private

// view & pure functions
