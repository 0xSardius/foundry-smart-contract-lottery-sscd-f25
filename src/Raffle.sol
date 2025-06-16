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


/**
* @title Raffle
* @author @0xSardius
* @notice This contract is a raffle contract that allows users to enter a raffle and win a prize.
* @dev This contract uses Chainlink VRF 2.5 to randomly select a winner.
 */

contract Raffle {

    // Errors
    error Raffle__SendMoreEthToEnterRaffle();

    // State variables
    uint256 private immutable i_entranceFee;

    // Storage variable because players will change as they are added
    address payable[] private s_players;

     
     // Events (verb based naming convention)
     event RaffleEnter(address indexed player);

    constructor(uint256 entranceFee) {
        i_entranceFee = entranceFee;
    }

    function enterRaffle() public payable {
        // require(msg.value >= i_entranceFee, "Not enough ETH broke boy!");
        if (msg.value < i_entranceFee) {
            revert Raffle__SendMoreEthToEnterRaffle();
        }
        s_players.push(payable(msg.sender));
        emit RaffleEnter(msg.sender);
     }

    function pickWinner() public {

    }



    /**
     * View / Pure functions
     */
    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }

    function getPlayer(uint256 index) public view returns (address) {

    }

}
