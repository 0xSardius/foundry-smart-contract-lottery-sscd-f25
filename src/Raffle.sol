// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Contract Layout:
// version
// imports
// interfaces, libraries, contracts
// type declarations
// state variables
// events
// modifiers

// functions Layout:
// constructor
// receive functions (if exists)
// fallback functions (if exists)
// external functions
// public functions
// internal functions
// private functions

import {VRFCoordinatorV2Interface} from "lib/chainlink/contracts/src/v0.8/vrf/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFV2PlusClient} from "lib/chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import {VRFConsumerBaseV2Plus} from "lib/chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";

/**
 * @title Raffle
 * @author @0xSardius
 * @notice This contract is a raffle contract that allows users to enter a raffle and win a prize.
 * @dev This contract uses Chainlink VRF 2.5 to randomly select a winner.
 */
contract Raffle is VRFConsumerBaseV2Plus {
    // Errors
    error Raffle__SendMoreEthToEnterRaffle();
    error Raffle__RaffleNotReady();
    error Raffle__TransferFailed();
    error Raffle__RaffleNotOpen();
    error Raffle__UpkeepNotNeeded(uint256 balance, uint256 playersLength, uint256 s_raffleState);


    /* Type declarations */
    enum RaffleState {
        OPEN,
        CALCULATING
    }


    // State variables
    uint256 private immutable i_entranceFee;
    // @dev duration of the raffle in seconds
    uint256 private immutable i_interval;
    uint256 private s_lastTimeStamp;
    bytes32 private immutable i_keyhash;
    uint256 private immutable i_subId;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private immutable i_callbackGasLimit;
    uint32 private constant NUM_WORDS = 1;
    address private s_recentWinner;
    RaffleState private s_raffleState;

    // Storage variable because players will change as they are added
    address payable[] private s_players;

    

    // Events (verb based naming convention)
    event RaffleEnter(address indexed player);
    event WinnerPicked(address indexed winner);
    event RequestedRaffleWinner(uint256 indexed requestId);

    constructor(uint256 entranceFee, uint256 interval, address vrfCoordinator, bytes32 gasLane, uint256 subId, uint32 callbackGasLimit) VRFConsumerBaseV2Plus(vrfCoordinator) {
        i_entranceFee = entranceFee;
        i_interval = interval;
        i_keyhash = gasLane;
        i_subId = subId;
        i_callbackGasLimit = callbackGasLimit;

        s_lastTimeStamp = block.timestamp;
        s_raffleState = RaffleState.OPEN;
    }

    function enterRaffle() public payable {
        // require(msg.value >= i_entranceFee, "Not enough ETH broke boy!");
        if (msg.value < i_entranceFee) {
            revert Raffle__SendMoreEthToEnterRaffle();
        }
        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle__RaffleNotOpen();
        }
        s_players.push(payable(msg.sender));
        emit RaffleEnter(msg.sender);
    }
    
    // When should the winner be picked?
    /**
    @dev This is the function that the Chainlink Nodes will use to see if the lottery is ready to have a winner picked
    The following should be true in order to call this function:
    * 1. The lottery is open
    * 2. There is at least 1 player in the lottery
    * 3. The contract has ETH
    * 4. The time interval has passed
     */ 
    function checkUpkeep(bytes memory /* checkData */) public view returns (bool upkeepNeeded, bytes memory /* performData */) {
        // Check
        bool timeHasPassed = (block.timestamp - s_lastTimeStamp) > i_interval;
        bool isOpen = s_raffleState == RaffleState.OPEN;
        bool hasPlayers = s_players.length > 0;
        bool hasBalance = address(this).balance > 0;
        upkeepNeeded = (timeHasPassed && isOpen && hasPlayers && hasBalance);
        // Effects
        

        // Interactions
        return (upkeepNeeded, "");
    }

    function performUpkeep(bytes calldata /* performData */) external {
        // check
        // calldata can only be generated from a user's transaction 
        (bool upkeepNeeded, ) = checkUpkeep("");
        if (!upkeepNeeded) {
            revert Raffle__UpkeepNotNeeded(address(this).balance, s_players.length, uint256(s_raffleState));
        }

        // Effects
        s_raffleState = RaffleState.CALCULATING;
    }

    // 1. Get a random number
    // 2. Use a random number to pick a winner
    // 3. Send the prize to the winner
    function pickWinner() external {
        if ((block.timestamp - s_lastTimeStamp) < i_interval) {
            revert Raffle__RaffleNotReady();
        }

        s_raffleState = RaffleState.CALCULATING;
      VRFV2PlusClient.RandomWordsRequest memory request = VRFV2PlusClient.RandomWordsRequest({
                keyHash: i_keyhash,
                subId: i_subId,
                requestConfirmations: REQUEST_CONFIRMATIONS,
                callbackGasLimit: i_callbackGasLimit,
                numWords: NUM_WORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({nativePayment: true})) // new parameter
            });

        uint256 requestId = s_vrfCoordinator.requestRandomWords(request);
        emit RequestedRaffleWinner(requestId);
    }

    // CEI: Checks, Effects, Interactions

    function fulfillRandomWords(uint256 /* requestId */, uint256[] calldata randomWords) internal override {
        // Checks
        // None in this example


        // Effects (Internal Contract Changes, state changes, etc.)
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable recentWinner = s_players[indexOfWinner];


        s_recentWinner = recentWinner;
        s_raffleState = RaffleState.OPEN;
        s_players = new address payable[](0);   
        s_lastTimeStamp = block.timestamp;
        // Events can be tricky, so we should do before external interactions for securityated
        emit WinnerPicked(recentWinner);

        // Interactions - External contract interactions, external calls, etc.
        (bool success, ) = recentWinner.call{value: address(this).balance}("");
        if (!success) {
            revert Raffle__TransferFailed();
        }
        
    }
    /**
     * View / Pure functions
     */
    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }

    function getRaffleState() external view returns (RaffleState) {
        return s_raffleState;
    }

    function getPlayer(uint256 indexOfPlayer) external view returns (address) {
        return s_players[indexOfPlayer];
    }

    function getLastTimeStamp() external view returns (uint256) {
        return s_lastTimeStamp;
    }

    function getRecentWinner() external view returns (address) {
        return s_recentWinner;
    }
}