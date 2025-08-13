// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "lib/forge-std/src/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "./Interactions.s.sol";

contract DeployRaffle is Script {
    Raffle public raffle;

    function setUp() public {}

    function run() public returns(Raffle, HelperConfig) {
        return deployContract();
    }

    function deployContract() public returns(Raffle, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        // local -> deploy mocks, get local config
        // sepolia -> get sepolia config
        HelperConfig.NetworkConfig memory networkConfig = helperConfig.getConfig();

        if (networkConfig.subscriptionId == 0) {
            CreateSubscription createSubscription = new CreateSubscription();
            (networkConfig.subscriptionId, networkConfig.vrfCoordinator) = createSubscription.createSubscription(networkConfig.vrfCoordinator);

            // Fund that shit!
            FundSubscription fundSubscription = new FundSubscription();
            fundSubscription.fundSubscription(networkConfig.vrfCoordinator, networkConfig.subscriptionId, networkConfig.link);
        }
        
        vm.startBroadcast();
        Raffle deployedRaffle = new Raffle(
            networkConfig.entranceFee,
            networkConfig.interval,
            networkConfig.vrfCoordinator,
            networkConfig.gasLane,
            networkConfig.subscriptionId,
            networkConfig.callbackGasLimit
        );
        vm.stopBroadcast();

        AddConsumer addConsumer = new AddConsumer();
        // Don't need to broadcast, 
        addConsumer.addConsumer(address(raffle), networkConfig.vrfCoordinator, networkConfig.subscriptionId);
        
        return (deployedRaffle, helperConfig);
    }
}
