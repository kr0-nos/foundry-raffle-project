// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {Vm} from "forge-std/Vm.sol";
import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/Script.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {Raffle} from "src/Raffle.sol";
import {HelperConfig, CodeConstants} from "../../script/HelperConfig.s.sol";

contract RaffleTest is Test, CodeConstants {
    Raffle public raffle;
    HelperConfig public helperConfig;

    address public user_A = makeAddr("user_A");
    address public user_B = makeAddr("user_B");

    uint256 public constant STARTING_BALANCE = 10 ether;

    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint32 callbackGasLimit;
    uint256 subscriptionId;

    event RaffleEntered(address indexed player);
    event WinnerPicked(address indexed winner);

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();

        (raffle, helperConfig) = deployer.deployContract();

        HelperConfig.NetworkConfig memory config = helperConfig.getConfig(); // we can directly access enums/structs/defined type even without inheriting/instantiating the contract they're from.

        entranceFee = config.entranceFee;
        interval = config.interval;
        vrfCoordinator = config.vrfCoordinator;
        gasLane = config.gasLane;
        callbackGasLimit = config.callbackGasLimit;
        subscriptionId = config.subscriptionId;
        vm.deal(user_A, STARTING_BALANCE);
        vm.deal(user_B, STARTING_BALANCE);
    }

    function testRaffleStartOpen() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    function testEnoughEthPaidToEnter() public {
        vm.deal(user_A, STARTING_BALANCE);
        vm.prank(user_A);
        vm.expectRevert(Raffle.Raffle__NotEnoughEth.selector);
        raffle.enterRaffle{value: 0.005 ether}();
    }

    function testarePlayeredRegistered() public {
        vm.deal(user_A, STARTING_BALANCE);
        vm.prank(user_A);
        raffle.enterRaffle{value: 0.1 ether}();
        // we put the [] on payable instead of address because making an array of address payable is non sense, we're instead making the payable address array
        address payable[] memory players = raffle.getPlayers();
        assertEq(players.length, 1);
    }

    function testIsParticipantUserA() public {
        vm.prank(user_A);
        raffle.enterRaffle{value: 0.5 ether}();
        address playerEntered = raffle.getUser(0);
        assert(playerEntered == user_A);
    }

    function testEnteringRaffleEmitsEven() public {
        vm.prank(user_A);
        // cheatcode to tell that the next external call should emit an event from address(raffle)
        vm.expectEmit(true, false, false, false, address(raffle));
        // providing a template to foundry to tell what the event should look like
        emit RaffleEntered(user_A);
        // actual function call that does emit the event
        raffle.enterRaffle{value: 0.5 ether}();
    }

    function testDontAllowPlayersToEnterWhileRaffleIsCalculating() public {
        vm.prank(user_A);

        // need to simulate condition for Raffle.RaffleState to be = calculating
        raffle.enterRaffle{value: entranceFee}();
        // now need to set timeHasPassed
        vm.warp(block.timestamp + interval + 1);
        // change block number (best practice, bc time has passed, chances are block advanced)
        vm.roll(block.number + 1);

        raffle.performUpkeep("");

        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);

        vm.prank(user_B);

        raffle.enterRaffle{value: entranceFee}();
    }

    function testCheckUpkeepReturnsFalseIfItHasNoBalance() public {
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        
        assert(!upkeepNeeded);
    }

    function testCheckUpkeepReturnsFalseIfRaffleIsntOpen() public {

        vm.prank(user_A);

        // need to simulate condition for Raffle.RaffleState to be = calculating
        raffle.enterRaffle{value: entranceFee}();
        // now need to set timeHasPassed
        vm.warp(block.timestamp + interval + 1);
        // change block number (best practice, bc time has passed, chances are block advanced)
        vm.roll(block.number + 1);

        raffle.performUpkeep("");


        (bool upkeepNeeded,) = raffle.checkUpkeep("");
        assert(!upkeepNeeded);
    }

    function testCheckUpkeepReturnsFalseIfEnoughTimeHasPassed() public {


        (bool timeHasPassed, ) = raffle.checkUpkeep("");

        assert(!timeHasPassed);
    }

    function testCheckUpkeepReturnsTrueIfEnoughTimeHasPassed() public {
        uint256 initialBlockTimestamp = block.timestamp;
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        bool timeHasPassed = ((block.timestamp - initialBlockTimestamp) >= raffle.i_interval());
        assert(timeHasPassed);



    }

    function testCheckUpkeepReturnsTrueWhenParametersAreGood() public {

        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        vm.prank(user_A);
        raffle.enterRaffle{value: entranceFee}();

        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        assert(upkeepNeeded);

    }

    function testPerformUpkeepCanOnlyRunIfCheckUpkeepIsTrue() public {

        vm.prank(user_A);
        raffle.enterRaffle{value: entranceFee}();

        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        raffle.performUpkeep("");

    }

    function testPerformUpkeepRevertIfCheckUpkeepIsFalse() public {

        Raffle.RaffleState rState = raffle.getRaffleState();
        // vm.expectRevert needs to know what the actual revert data from the EVM will look like in order
        // to compare it. That's why we need to abi.encode these parameters along with the selector
        vm.expectRevert(
            abi.encodeWithSelector(Raffle.Raffle__UpkeepNotNeeded.selector, 0, 0, rState)
        );
        raffle.performUpkeep("");

    }
    modifier raffleEntered(){
        vm.prank(user_A);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;

    }

    modifier skipFork(){
        if(block.chainid != LOCAL_CHAIN_ID){
            return;
        }
        _;
    }

    function testPerformUpkeepUpdatesRaffleStateAndEmitsRequestId() public raffleEntered {
        
        vm.recordLogs();
        raffle.performUpkeep("");

        Vm.Log[] memory entries = vm.getRecordedLogs();
        // not checking zero because it would correspond to the event emitted by
        // vrfCoordinator
        bytes32 requestId = entries[1].topics[1];

        Raffle.RaffleState raffleState = raffle.getRaffleState();

        assert(uint256(requestId) > 0);

        assert(uint256(raffleState) == 1 );
        
    }

    function testFulfillrandomWordsCanOnlyBeCalledAfterPerformUpkeep(uint256 randomRequestId) public raffleEntered skipFork {

        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(randomRequestId, address(raffle));

    }

    function testFulfillrandomWordsPicksAWinnerResetsAndSendsMoney() public raffleEntered skipFork {
        // adding 3 other participants
        
        uint256 additionalEntrants = 3;

        uint256 startingIndex = 1;

        for(uint256 i = startingIndex; i<startingIndex + additionalEntrants; i++){
            address newPlayer = address(uint160(i));
            hoax(newPlayer, 10 ether);
            raffle.enterRaffle{value: entranceFee}();
        }

        /* uint256 subscriptionId = raffle.getSubscriptionId();
        uint256 amountToBeFundedSubscription = 100 ether;
        VRFCoordinatorV2_5Mock(vrfCoordinator).fundSubscription(subscriptionId, amountToBeFundedSubscription);
 */
        uint256 lastTimeStamp = raffle.getLastTimestamp();

        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];
        
        
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(uint256(requestId), address(raffle));
        address recentWinner = raffle.getRecentWinner();
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        uint256 winnerBalance = recentWinner.balance;
        uint256 endingTimeStamp = raffle.getLastTimestamp();
        // prize pool
        uint256 prize = entranceFee * (additionalEntrants + 1);

        assert(recentWinner != address(0));
        assert(winnerBalance > 0);
        assert(endingTimeStamp - lastTimeStamp > 0);






    }

}
