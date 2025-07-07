// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.30;

import {Test} from "forge-std/Test.sol";
import {DeployRaffle} from "script/DeployRaffle.s.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {Raffle} from "src/Raffle.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

contract RaffleTest is Test {
    Raffle public raffle;
    HelperConfig helperConfig;

    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 keyHash;
    uint256 subscriptionId;
    uint32 callbackGasLimit;

    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_PLAYER_BALANCE = 10 ether;

    event RaffleEntered(address indexed player);

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.deployContract();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        entranceFee = config.entranceFee;
        interval = config.interval;
        vrfCoordinator = config.vrfCoordinator;
        keyHash = config.keyHash;
        callbackGasLimit = config.callbackGasLimit;
        subscriptionId = config.subscriptionId;
        vm.deal(PLAYER, STARTING_PLAYER_BALANCE);
    }

    function testRaffleInitializesInOpenState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    /* Test enterRaffle */

    function testRaffleRevertsWhenNoEthPayed() public {
        // Arrange
        vm.prank(PLAYER);
        // Act + Assert
        vm.expectRevert(Raffle.Raffle__NotEnoughEthToEnterRaffle.selector);
        raffle.enterRaffle{value: 0}(); // same as: raffle.enterRaffle();
    }

    function testRaffleRevertsWhenNotEnoughEthPayed() public {
        // Arrange
        vm.prank(PLAYER);
        // Act + Assert
        vm.expectRevert(Raffle.Raffle__NotEnoughEthToEnterRaffle.selector);
        raffle.enterRaffle{value: entranceFee - 1}();
    }

    function testPreventEnteringWhenRaffleNotOpen() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep(""); // raffle will calculate the winner now
        vm.prank(PLAYER);
        // Act + Assert
        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        raffle.enterRaffle{value: entranceFee}();
    }

    function testRaffleRecordsEnteredPlayer() public {
        // Arrange
        vm.prank(PLAYER);
        // Act
        raffle.enterRaffle{value: entranceFee}();
        // Assert
        assert(raffle.getPlayer(0) == PLAYER);
    }

    function testEnteringRaffleEmitsEvent() public {
        // Arrange
        vm.prank(PLAYER);
        // Act + Assert
        vm.expectEmit(true, false, false, false, address(raffle));
        emit RaffleEntered(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
    }

    /* Test checkUpkeep */

    function testCheckUpkeepReturnsFalseIfTimeHasNotPassed() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval - 1); // -1 -> not enough time is warped
        vm.roll(block.number + 1);
        // Act
        (bool upkeepNeeded,) = raffle.checkUpkeep("");
        // Assert
        assertFalse(upkeepNeeded);
    }

    function testCheckUpkeepReturnsFalseIfRaffleIsNotOpen() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep(""); // raffle will go into calculating state now
        // Act
        (bool upkeepNeeded,) = raffle.checkUpkeep("");
        // Assert
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        assertFalse(upkeepNeeded);
        assert(raffleState == Raffle.RaffleState.CALCULATING);
    }

    function testCheckUpkeepReturnsFalseIfRaffleHasNoBalanceAndNoPlayers() public {
        // Arrange
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        // Act
        (bool upkeepNeeded,) = raffle.checkUpkeep("");
        // Assert
        assertFalse(upkeepNeeded);
    }

    function testUpkeepReturnsTrueIfParametersAreGood() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        // Act
        (bool upkeepNeeded,) = raffle.checkUpkeep("");
        // Assert
        assert(upkeepNeeded);
    }

    /* Test performUpkeep */

    modifier raffleEntered() {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    function testPerformUpkeepRunsIfCheckUpkeepIsTrue() public raffleEntered {
        // Arrange (-> modifier)
        // Act
        (bool upkeepNeeded,) = raffle.checkUpkeep("");
        // Assert
        raffle.performUpkeep(""); // ok if it does not revert
        assert(upkeepNeeded);
    }

    function testPerformUpkeepRevertsIfCheckUpkeepIsFalse() public {
        // Arrange
        uint256 numPlayers = 0;
        uint256 currentBalance = 0;
        Raffle.RaffleState raffleState = raffle.getRaffleState();

        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        currentBalance += entranceFee;
        numPlayers += 1;
        // Time is not warped -> checkUpkeep will return false

        // Act + Assert
        vm.expectRevert(
            abi.encodeWithSelector(Raffle.Raffle__UpkeepNotNeeded.selector, currentBalance, numPlayers, raffleState)
        );
        raffle.performUpkeep("");
    }

    function testPerformUpkeepUpdatesRaffleStateEmitRequestId() public raffleEntered {
        // Arrange (-> modifier)
        // Act
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];
        // entries[0] is an event emitted by the VRF coordinator mock prior to ours
        // topics[0] is reserved

        // Assert
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        assert(raffleState == Raffle.RaffleState.CALCULATING);
        assert(uint256(requestId) > 0);
    }

    /* Test fullfilRandomWords */

    function testFullfilRandomWordsCanOnlyBeCalledAfterPerformUpkeep(uint256 randomRequestId) public raffleEntered {
        // Arrange (-> modifier)
        // Act + Assert
        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        // Fuzz test with many requestId
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(randomRequestId, address(raffle));
    }

    function testFulfillRandomWordsPicksAWinnerResetsAndSendsMoney() public raffleEntered {
        // Arrange: Let 3 more players enter the raffle (1st entered through the modifier)
        uint256 additionalPlayers = 3; // 4 total
        uint256 startingIdx = 1;
        address expectedWinner = address(1);

        for (uint256 i = startingIdx; i < startingIdx + additionalPlayers; i++) {
            address newPlayer = address(uint160(i));
            hoax(newPlayer, 1 ether);
            raffle.enterRaffle{value: entranceFee}();
        }
        uint256 startingTimeStamp = raffle.getLastTimeStamp();
        uint256 winnerStartingBalance = expectedWinner.balance;

        // Act: Make VRF request and get requestId
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];
        // Simulate being the VRF node and return the random number
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(uint256(requestId), address(raffle));

        // Assert: Raffle resets and money is transferred
        address recentWinner = raffle.getRecentWinner();
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        uint256 winnerBalance = recentWinner.balance;
        uint256 endingTimeStamp = raffle.getLastTimeStamp();
        uint256 prize = entranceFee * (additionalPlayers + 1);

        assert(recentWinner == expectedWinner);
        assert(raffleState == Raffle.RaffleState.OPEN);
        assert(winnerBalance == winnerStartingBalance + prize);
        assert(endingTimeStamp == startingTimeStamp + interval + 1);
    }
}
