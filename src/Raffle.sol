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

import {VRFCoordinatorV2Interface} from "chainlink/contracts/src/v0.8/vrf/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFV2PlusClient} from "chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import {VRFConsumerBaseV2Plus} from "chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";

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

    // Storage variable because players will change as they are added
    address payable[] private s_players;

    // Events (verb based naming convention)
    event RaffleEnter(address indexed player);

    constructor(uint256 entranceFee, uint256 interval, address vrfCoordinator, bytes32 gasLane, uint256 subId, uint32 callbackGasLimit) VRFConsumerBaseV2Plus(vrfCoordinator) {
        i_entranceFee = entranceFee;
        i_interval = interval;
        s_lastTimeStamp = block.timestamp;
        i_keyhash = gasLane;
        i_subId = subId;
        i_callbackGasLimit = callbackGasLimit;
    }

    function enterRaffle() public payable {
        // require(msg.value >= i_entranceFee, "Not enough ETH broke boy!");
        if (msg.value < i_entranceFee) {
            revert Raffle__SendMoreEthToEnterRaffle();
        }
        s_players.push(payable(msg.sender));
        emit RaffleEnter(msg.sender);
    }

    // 1. Get a random number
    // 2. Use a random number to pick a winner
    // 3. Send the prize to the winner
    function pickWinner() external {
        if ((block.timestamp - s_lastTimeStamp) < i_interval) {
            revert Raffle__RaffleNotReady();
        }
      VRFV2PlusClient.RandomWordsRequest memory request = VRFV2PlusClient.RandomWordsRequest({
                keyHash: i_keyhash,
                subId: i_subId,
                requestConfirmations: REQUEST_CONFIRMATIONS,
                callbackGasLimit: i_callbackGasLimit,
                numWords: NUM_WORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({nativePayment: true})) // new parameter
            });

    }

    /**
     * View / Pure functions
     */
    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }

    function getPlayer(uint256 index) public view returns (address) {}
}
