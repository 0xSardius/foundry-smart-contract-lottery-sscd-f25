// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";

contract DeployRaffle is Script {
    Raffle public raffle;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        raffle = new Raffle();

        vm.stopBroadcast();
    }

    function deployContract() public returns(Raffle, HelperConfig) {
    
    }
}
