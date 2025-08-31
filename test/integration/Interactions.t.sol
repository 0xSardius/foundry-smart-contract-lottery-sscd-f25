// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "lib/forge-std/src/Test.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "../../script/Interactions.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Raffle} from "../../src/Raffle.sol";
import {VRFCoordinatorV2_5Mock} from "lib/chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "../mocks/LinkToken.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

/**
 * @title InteractionsTest
 * @author @0xSardius
 * @notice Integration tests for deployment scripts and interaction contracts
 * @dev Tests the complete deployment flow and all interaction scripts
 */
contract InteractionsTest is Test {
    // Test contracts
    DeployRaffle public deployer;
    CreateSubscription public createSubscription;
    FundSubscription public fundSubscription;
    AddConsumer public addConsumer;
    
    // Core contracts
    Raffle public raffle;
    HelperConfig public helperConfig;
    HelperConfig.NetworkConfig public networkConfig;
    
    // Mock contracts
    VRFCoordinatorV2_5Mock public vrfCoordinatorMock;
    LinkToken public linkToken;
    
    // Test addresses
    address public PLAYER = makeAddr("PLAYER");
    address public DEPLOYER = makeAddr("DEPLOYER");
    uint256 public constant STARTING_BALANCE = 100 ether;
    uint256 public constant FUND_AMOUNT = 3 ether;

    // Events to test
    event RaffleEnter(address indexed player);
    event WinnerPicked(address indexed winner);
    event RequestedRaffleWinner(uint256 indexed requestId);

    function setUp() public {
        // Setup test accounts
        vm.deal(PLAYER, STARTING_BALANCE);
        vm.deal(DEPLOYER, STARTING_BALANCE);
        
        // Initialize deployment script
        deployer = new DeployRaffle();
        
        // Initialize interaction scripts
        createSubscription = new CreateSubscription();
        fundSubscription = new FundSubscription();
        addConsumer = new AddConsumer();
    }

    //////////////////////////////////////////////////////////////
    ///////////////////////// DEPLOYMENT TESTS //////////////////
    //////////////////////////////////////////////////////////////

    function testDeployRaffleCreatesValidContract() public {
        // Act
        vm.prank(DEPLOYER);
        (Raffle deployedRaffle, HelperConfig deployedHelperConfig) = deployer.run();
        
        // Assert
        assertTrue(address(deployedRaffle) != address(0), "Raffle should be deployed");
        assertTrue(address(deployedHelperConfig) != address(0), "HelperConfig should be deployed");
        
        // Verify raffle is initialized correctly
        assertEq(uint256(deployedRaffle.getRaffleState()), 0, "Raffle should start in OPEN state");
        assertTrue(deployedRaffle.getEntranceFee() > 0, "Entrance fee should be set");
    }

    function testDeployRaffleWithMocksOnLocalChain() public {
        // Arrange - Force local chain
        vm.chainId(31337);
        
        // Act
        vm.prank(DEPLOYER);
        (Raffle deployedRaffle, HelperConfig deployedHelperConfig) = deployer.run();
        HelperConfig.NetworkConfig memory config = deployedHelperConfig.getConfig();
        
        // Assert
        assertTrue(address(deployedRaffle) != address(0), "Raffle should be deployed");
        assertTrue(config.vrfCoordinator != address(0), "VRF Coordinator should be deployed");
        assertTrue(config.link != address(0), "Link token should be deployed");
        assertTrue(config.subscriptionId > 0, "Subscription should be created");
        
        // Verify mocks are properly configured
        VRFCoordinatorV2_5Mock coordinator = VRFCoordinatorV2_5Mock(config.vrfCoordinator);
        assertTrue(coordinator.consumerIsAdded(config.subscriptionId, address(deployedRaffle)), 
                  "Raffle should be added as consumer");
    }

    function testDeployRaffleCreatesAndFundsSubscription() public {
        // Arrange
        vm.chainId(31337);
        
        // Act
        vm.prank(DEPLOYER);
        (Raffle deployedRaffle, HelperConfig deployedHelperConfig) = deployer.run();
        HelperConfig.NetworkConfig memory config = deployedHelperConfig.getConfig();
        
        // Assert
        VRFCoordinatorV2_5Mock coordinator = VRFCoordinatorV2_5Mock(config.vrfCoordinator);
        
        // Check subscription exists and is funded
        assertTrue(config.subscriptionId > 0, "Subscription ID should be set");
        
        // Check subscription balance (should be funded)
        (uint96 balance,,,) = coordinator.getSubscription(config.subscriptionId);
        assertTrue(balance > 0, "Subscription should be funded");
        
        // Check consumer is added
        assertTrue(coordinator.consumerIsAdded(config.subscriptionId, address(deployedRaffle)), 
                  "Raffle should be added as consumer");
    }

    //////////////////////////////////////////////////////////////
    /////////////////////// INTERACTION TESTS ///////////////////
    //////////////////////////////////////////////////////////////

    function testCreateSubscriptionScript() public {
        // Arrange
        vm.chainId(31337);
        HelperConfig config = new HelperConfig();
        HelperConfig.NetworkConfig memory networkConfig = config.getConfig();
        
        // Act
        vm.prank(DEPLOYER);
        (uint256 subId, address vrfCoord) = createSubscription.createSubscription(networkConfig.vrfCoordinator);
        
        // Assert
        assertTrue(subId > 0, "Subscription ID should be greater than 0");
        assertEq(vrfCoord, networkConfig.vrfCoordinator, "VRF Coordinator should match");
        
        // Verify subscription exists on coordinator
        VRFCoordinatorV2_5Mock coordinator = VRFCoordinatorV2_5Mock(networkConfig.vrfCoordinator);
        (uint96 balance, uint64 reqCount,,) = coordinator.getSubscription(subId);
        assertEq(reqCount, 0, "Request count should be 0 for new subscription");
    }

    function testCreateSubscriptionUsingConfig() public {
        // Arrange
        vm.chainId(31337);
        
        // Act
        vm.prank(DEPLOYER);
        (uint256 subId, address vrfCoord) = createSubscription.createSubscriptionUsingConfig();
        
        // Assert
        assertTrue(subId > 0, "Subscription ID should be greater than 0");
        assertTrue(vrfCoord != address(0), "VRF Coordinator address should be valid");
    }

    function testFundSubscriptionOnLocalChain() public {
        // Arrange
        vm.chainId(31337);
        HelperConfig config = new HelperConfig();
        HelperConfig.NetworkConfig memory networkConfig = config.getConfig();
        
        // Create subscription first
        vm.prank(DEPLOYER);
        (uint256 subId,) = createSubscription.createSubscription(networkConfig.vrfCoordinator);
        
        // Act
        vm.prank(DEPLOYER);
        fundSubscription.fundSubscription(networkConfig.vrfCoordinator, subId, networkConfig.link);
        
        // Assert
        VRFCoordinatorV2_5Mock coordinator = VRFCoordinatorV2_5Mock(networkConfig.vrfCoordinator);
        (uint96 balance,,,) = coordinator.getSubscription(subId);
        assertEq(balance, FUND_AMOUNT * 100, "Subscription should be funded with correct amount for local chain");
    }

    function testFundSubscriptionUsingConfig() public {
        // Arrange
        vm.chainId(31337);
        
        // Create a subscription first
        vm.prank(DEPLOYER);
        (uint256 subId, address vrfCoord) = createSubscription.createSubscriptionUsingConfig();
        
        // Update helper config with the subscription ID for funding
        HelperConfig config = new HelperConfig();
        HelperConfig.NetworkConfig memory networkConfig = config.getConfig();
        
        // Act
        vm.prank(DEPLOYER);
        fundSubscription.fundSubscription(vrfCoord, subId, networkConfig.link);
        
        // Assert
        VRFCoordinatorV2_5Mock coordinator = VRFCoordinatorV2_5Mock(vrfCoord);
        (uint96 balance,,,) = coordinator.getSubscription(subId);
        assertTrue(balance > 0, "Subscription should be funded");
    }

    function testAddConsumerScript() public {
        // Arrange
        vm.chainId(31337);
        HelperConfig config = new HelperConfig();
        HelperConfig.NetworkConfig memory networkConfig = config.getConfig();
        
        // Create and fund subscription
        vm.prank(DEPLOYER);
        (uint256 subId,) = createSubscription.createSubscription(networkConfig.vrfCoordinator);
        
        vm.prank(DEPLOYER);
        fundSubscription.fundSubscription(networkConfig.vrfCoordinator, subId, networkConfig.link);
        
        // Deploy a test contract to add as consumer
        vm.prank(DEPLOYER);
        Raffle testRaffle = new Raffle(
            0.01 ether,
            30,
            networkConfig.vrfCoordinator,
            networkConfig.gasLane,
            subId,
            500000
        );
        
        // Act
        vm.prank(DEPLOYER);
        addConsumer.addConsumer(address(testRaffle), networkConfig.vrfCoordinator, subId);
        
        // Assert
        VRFCoordinatorV2_5Mock coordinator = VRFCoordinatorV2_5Mock(networkConfig.vrfCoordinator);
        assertTrue(coordinator.consumerIsAdded(subId, address(testRaffle)), 
                  "Test raffle should be added as consumer");
    }

    //////////////////////////////////////////////////////////////
    /////////////////// END-TO-END INTEGRATION TESTS ////////////
    //////////////////////////////////////////////////////////////

    function testCompleteDeploymentAndRaffleFlow() public {
        // Arrange
        vm.chainId(31337);
        
        // Act - Deploy everything
        vm.prank(DEPLOYER);
        (Raffle deployedRaffle, HelperConfig deployedHelperConfig) = deployer.run();
        HelperConfig.NetworkConfig memory config = deployedHelperConfig.getConfig();
        
        // Test the raffle works end-to-end
        vm.prank(PLAYER);
        deployedRaffle.enterRaffle{value: config.entranceFee}();
        
        // Fast forward time and trigger upkeep
        vm.warp(block.timestamp + config.interval + 1);
        vm.roll(block.number + 1);
        
        // Check upkeep and perform it
        (bool upkeepNeeded,) = deployedRaffle.checkUpkeep("");
        assertTrue(upkeepNeeded, "Upkeep should be needed");
        
        vm.prank(DEPLOYER);
        deployedRaffle.performUpkeep("");
        
        // Assert
        assertEq(uint256(deployedRaffle.getRaffleState()), 1, "Raffle should be in CALCULATING state");
        assertEq(deployedRaffle.getPlayer(0), PLAYER, "Player should be recorded");
        assertTrue(address(deployedRaffle).balance >= config.entranceFee, "Contract should have player's fee");
    }

    function testMultiplePlayersRaffleFlow() public {
        // Arrange
        vm.chainId(31337);
        vm.prank(DEPLOYER);
        (Raffle deployedRaffle, HelperConfig deployedHelperConfig) = deployer.run();
        HelperConfig.NetworkConfig memory config = deployedHelperConfig.getConfig();
        
        // Add multiple players
        address[] memory players = new address[](5);
        for (uint256 i = 0; i < 5; i++) {
            players[i] = makeAddr(string(abi.encodePacked("PLAYER_", i)));
            vm.deal(players[i], STARTING_BALANCE);
            
            vm.prank(players[i]);
            deployedRaffle.enterRaffle{value: config.entranceFee}();
        }
        
        // Act - Trigger raffle completion
        vm.warp(block.timestamp + config.interval + 1);
        vm.roll(block.number + 1);
        
        vm.prank(DEPLOYER);
        deployedRaffle.performUpkeep("");
        
        // Simulate VRF response
        VRFCoordinatorV2_5Mock coordinator = VRFCoordinatorV2_5Mock(config.vrfCoordinator);
        vm.recordLogs();
        vm.prank(DEPLOYER);
        deployedRaffle.performUpkeep("");
        
        // Get request ID from logs and fulfill
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId;
        for (uint256 i = 0; i < entries.length; i++) {
            if (entries[i].topics.length > 0 && 
                entries[i].topics[0] == keccak256("RequestedRaffleWinner(uint256)")) {
                requestId = entries[i].topics[1];
                break;
            }
        }
        
        uint256 initialBalance = address(deployedRaffle).balance;
        coordinator.fulfillRandomWords(uint256(requestId), address(deployedRaffle));
        
        // Assert
        address winner = deployedRaffle.getRecentWinner();
        assertTrue(winner != address(0), "Winner should be selected");
        assertEq(uint256(deployedRaffle.getRaffleState()), 0, "Raffle should be back to OPEN");
        assertEq(address(deployedRaffle).balance, 0, "Contract should have no balance after payout");
        
        // Check if winner is one of our players
        bool isValidWinner = false;
        for (uint256 i = 0; i < players.length; i++) {
            if (winner == players[i]) {
                isValidWinner = true;
                break;
            }
        }
        assertTrue(isValidWinner, "Winner should be one of the entered players");
    }

    function testSubscriptionManagementFlow() public {
        // Arrange
        vm.chainId(31337);
        HelperConfig config = new HelperConfig();
        HelperConfig.NetworkConfig memory networkConfig = config.getConfig();
        
        // Act - Create subscription
        vm.prank(DEPLOYER);
        (uint256 subId, address vrfCoord) = createSubscription.createSubscription(networkConfig.vrfCoordinator);
        
        // Fund subscription
        vm.prank(DEPLOYER);
        fundSubscription.fundSubscription(vrfCoord, subId, networkConfig.link);
        
        // Deploy raffle
        vm.prank(DEPLOYER);
        Raffle testRaffle = new Raffle(
            0.01 ether,
            30,
            vrfCoord,
            networkConfig.gasLane,
            subId,
            500000
        );
        
        // Add consumer
        vm.prank(DEPLOYER);
        addConsumer.addConsumer(address(testRaffle), vrfCoord, subId);
        
        // Assert
        VRFCoordinatorV2_5Mock coordinator = VRFCoordinatorV2_5Mock(vrfCoord);
        (uint96 balance,,,) = coordinator.getSubscription(subId);
        
        assertTrue(subId > 0, "Subscription should be created");
        assertTrue(balance > 0, "Subscription should be funded");
        assertTrue(coordinator.consumerIsAdded(subId, address(testRaffle)), 
                  "Raffle should be added as consumer");
    }

    //////////////////////////////////////////////////////////////
    ///////////////////////// ERROR TESTS ///////////////////////
    //////////////////////////////////////////////////////////////

    function testAddConsumerFailsWithInvalidSubscription() public {
        // Arrange
        vm.chainId(31337);
        HelperConfig config = new HelperConfig();
        HelperConfig.NetworkConfig memory networkConfig = config.getConfig();
        
        address dummyContract = makeAddr("DUMMY");
        uint256 invalidSubId = 999999;
        
        // Act & Assert
        vm.prank(DEPLOYER);
        vm.expectRevert();
        addConsumer.addConsumer(dummyContract, networkConfig.vrfCoordinator, invalidSubId);
    }

    function testFundSubscriptionFailsWithInvalidSubscription() public {
        // Arrange
        vm.chainId(31337);
        HelperConfig config = new HelperConfig();
        HelperConfig.NetworkConfig memory networkConfig = config.getConfig();
        
        uint256 invalidSubId = 999999;
        
        // Act & Assert
        vm.prank(DEPLOYER);
        vm.expectRevert();
        fundSubscription.fundSubscription(networkConfig.vrfCoordinator, invalidSubId, networkConfig.link);
    }

    //////////////////////////////////////////////////////////////
    ///////////////////////// HELPER FUNCTIONS //////////////////
    //////////////////////////////////////////////////////////////

    function testHelperConfigReturnsCorrectNetworkConfig() public {
        // Arrange
        vm.chainId(31337);
        HelperConfig config = new HelperConfig();
        
        // Act
        HelperConfig.NetworkConfig memory networkConfig = config.getConfig();
        
        // Assert
        assertEq(networkConfig.entranceFee, 0.01 ether, "Entrance fee should be 0.01 ether");
        assertEq(networkConfig.interval, 30, "Interval should be 30 seconds");
        assertTrue(networkConfig.vrfCoordinator != address(0), "VRF Coordinator should be deployed");
        assertTrue(networkConfig.link != address(0), "Link token should be deployed");
        assertEq(networkConfig.callbackGasLimit, 500000, "Callback gas limit should be 500000");
    }

    function testHelperConfigSepoliaConfig() public {
        // Arrange
        vm.chainId(11155111); // Sepolia chain ID
        HelperConfig config = new HelperConfig();
        
        // Act
        HelperConfig.NetworkConfig memory networkConfig = config.getConfig();
        
        // Assert
        assertEq(networkConfig.vrfCoordinator, 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B, 
                "Should use Sepolia VRF Coordinator");
        assertEq(networkConfig.link, 0x779877A7B0D9E8603169DdbD7836e478b4624789, 
                "Should use Sepolia Link token");
        assertEq(networkConfig.subscriptionId, 0, "Subscription ID should be 0 for Sepolia");
    }

    function testHelperConfigInvalidChainIdReverts() public {
        // Arrange
        vm.chainId(999999); // Invalid chain ID
        HelperConfig config = new HelperConfig();
        
        // Act & Assert
        vm.expectRevert(HelperConfig.HelperConfig__InvalidChainId.selector);
        config.getConfig();
    }
}
