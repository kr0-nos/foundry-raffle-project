// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
/**
 * @title A simple Raffle Contract
 * @author Samy-James Carnet
 * @notice This contract creates a raffle
 * @dev Implements ChainLink VRFv2.5
 */

contract Raffle is VRFConsumerBaseV2Plus {
    // errors
    error Raffle__NotEnoughEth();
    error Raffle__TransferFailed();
    error Raffle__RaffleNotOpen();
    error Raffle__UpkeepNotNeeded(uint256 balance, uint256 playersLength, uint256 raffleState);
    // type declarations
    enum RaffleState {
        OPEN, // 0
        CALCULATING // 1
    }

    uint256 private immutable i_entranceFee;
    // array of address needs to be payable, bc we need to pay the winner
    address payable[] private s_players;
    // @dev interval to pick a winner
    uint256 public immutable i_interval;
    uint256 private s_lastTimeStamp;
    bytes32 private immutable i_keyHash;
    uint256 private immutable i_subscriptionId;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private immutable i_callbackGasLimit;
    uint32 private constant NUM_WORDS = 1;
    address private s_recentWinner;
    RaffleState public s_raffleState;

    event RaffleEntered(address indexed player);
    event WinnerPicked(address indexed winner);
    event RequestRaffleWinner(uint256 indexed requestId);

    // our constructor needs to also implements the constructor of the contract we implement, and as it takes a vrfCoordinator variable, we must pass it via our own constructor lol
    constructor(
        uint256 entranceFee,
        uint256 interval,
        address vrfCoordinator,
        bytes32 gasLane,
        uint256 subscriptionId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2Plus(vrfCoordinator) {
        i_entranceFee = entranceFee;
        i_interval = interval;
        s_lastTimeStamp = block.timestamp;
        i_keyHash = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
        s_raffleState = RaffleState.OPEN;
    }

    function enterRaffle() external payable {
        //require(msg.value >= i_entranceFee, "Not enough ETH sent");
        if (msg.value < i_entranceFee) {
            revert Raffle__NotEnoughEth();
        }
        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle__RaffleNotOpen();
        }
        s_players.push(payable(msg.sender));

        emit RaffleEntered(msg.sender);
    }

    /**
     * @dev function that the chainlink nodes will call to see if lottery is ready to have a winner picked
     * this should be true in order for upkeepNeeded to be true:
     * 1. Time interval has passed between raffle runs
     * 2. Lottery is open
     * 3. Contract has ETH
     * 4. Implicitly, subscription has LINK
     */

    function checkUpkeep(bytes memory) public view returns (bool upkeepNeeded, bytes memory) {
        bool timeHasPassed = ((block.timestamp - s_lastTimeStamp) >= i_interval);

        bool isOpen = s_raffleState == RaffleState.OPEN;

        bool hasEth = address(this).balance > 0;

        bool hasPlayers = s_players.length > 0;

        upkeepNeeded = timeHasPassed && isOpen && hasEth && hasPlayers;

        return (upkeepNeeded, "");
    }

    // automatically called by chainlink upkeep
    function performUpkeep(bytes calldata) external {
        (bool upkeepNeeded,) = checkUpkeep("");
        if (!upkeepNeeded) {
            revert Raffle__UpkeepNotNeeded(address(this).balance, s_players.length, uint256(s_raffleState));
        }
        if (block.timestamp - s_lastTimeStamp < i_interval) {
            revert();
        }

        s_raffleState = RaffleState.CALCULATING;

        uint256 requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: i_keyHash,
                subId: i_subscriptionId,
                requestConfirmations: REQUEST_CONFIRMATIONS,
                callbackGasLimit: i_callbackGasLimit,
                numWords: NUM_WORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({nativePayment: false}))
            })
        );

        emit RequestRaffleWinner(requestId);

        // Getting our random number
    }

    function fulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) internal override {
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable recentWinner = s_players[indexOfWinner];
        s_recentWinner = recentWinner;

        s_raffleState = RaffleState.OPEN;
        s_players = new address payable[](0);
        s_lastTimeStamp = block.timestamp;
        emit WinnerPicked(s_recentWinner);

        (bool success,) = recentWinner.call{value: address(this).balance}("");

        if (!success) {
            revert Raffle__TransferFailed();
        }
    }
    /**
     * @notice Getter functions
     */

    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }

    function getRaffleState() external view returns (RaffleState) {
        return s_raffleState;
    }

    function getPlayers() external view returns (address payable[] memory) {
        return s_players;
    }

    function getUser(uint256 index) external view returns (address) {
        return s_players[index];
    }

    function getLastTimestamp() external view returns (uint256){
        return s_lastTimeStamp;
    }

    function getRecentWinner() external view returns (address){
        return s_recentWinner;
    }

    function getSubscriptionId() external view returns (uint256){
        return i_subscriptionId;
    }
}
