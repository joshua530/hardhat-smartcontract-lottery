// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/interfaces/KeeperCompatibleInterface.sol";

/* enter the lottery */
/* pick a random winner */
/* winner selected randomly every x minutes */
// chainlink oracle - for random functionality(chainlink keepers)

/*
=> VRF - Verifiable Random Function - a provably fair and verifiable random number 
generator (RNG) that enables smart contracts to access random values without 
compromising security or usability
=> block.timestamp - timestamp(since epoch) that the current block was mined
=> gas lane - sets the maximum amount of gas to be spent for a given request
*/

error Raffle__NotEnoughEthEntered();
error Raffle__TransferFailed();
error Raffle__NotOpen();
error Raffle__UpkeepNotNeeded(
  uint256 currentBalance,
  uint256 numPlayers,
  uint256 raffleState
);

/**
 * @title A sample raffle contract
 * @notice This contract is for creating an untamperable decentralized smart contract
 * @dev this implements chainlink vrf v2 and chainlink keepers
 */
contract Raffle is VRFConsumerBaseV2, KeeperCompatibleInterface {
  /* type declarations */
  enum RaffleState {
    OPEN,
    CALCULATING
  }

  /* state variables */
  uint256 private immutable i_entranceFee;
  address payable[] private s_players;
  VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
  bytes32 private immutable i_gasLane;
  uint64 private immutable i_subscriptionId;
  uint16 private constant REQUEST_CONFIRMATIONS = 3;
  uint32 private immutable i_callbackGasLimit;
  uint32 private constant NUM_WORDS = 1;
  // lotto variables
  address private s_recentWinner;
  RaffleState private s_raffleState;
  uint256 private s_lastTimeStamp;
  uint256 private immutable i_interval;

  /* events */
  // common way to write events is the function name in reverse
  event RaffleEnter(address indexed player);
  event RequestedRaffleWinner(uint256 indexed requestId);
  event WinnerPicked(address indexedWinner);

  constructor(
    address vrfCoordinatorV2,
    uint256 entranceFee, // amount required to buy raffle
    bytes32 gasLane, // sets ceiling of gwei to be used
    uint64 subscriptionId, // for funding the vrf request
    uint32 callbackGasLimit,
    uint256 interval
  ) VRFConsumerBaseV2(vrfCoordinatorV2) {
    i_entranceFee = entranceFee;
    i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinatorV2);
    i_gasLane = gasLane;
    i_subscriptionId = subscriptionId;
    i_callbackGasLimit = callbackGasLimit;
    s_raffleState = RaffleState.OPEN;
    s_lastTimeStamp = block.timestamp;
    i_interval = interval;
  }

  /**
   * events are written to the EVM log data structure
   * the evm log is not directly accessible by contracts
   */
  function enterRaffle() public payable {
    if (msg.value < i_entranceFee) {
      revert Raffle__NotEnoughEthEntered();
    }
    if (s_raffleState != RaffleState.OPEN) {
      revert Raffle__NotOpen();
    }
    s_players.push(payable(msg.sender));
    emit RaffleEnter(msg.sender);
  }

  /** checks whether random number/'word' should be requested from chainlink */
  function checkUpkeep(
    bytes memory /* checkData */
  )
    public
    view
    override
    returns (
      bool upkeepNeeded,
      bytes memory /* performData */
    )
  {
    // open
    // enough time has passed
    // enough players
    bool isOpen = (s_raffleState == RaffleState.OPEN);
    bool timePassed = (block.timestamp - s_lastTimeStamp) > i_interval;
    bool hasPlayers = (s_players.length > 0);
    bool hasBalance = address(this).balance > 0;
    upkeepNeeded = isOpen && timePassed && hasPlayers && hasBalance;
  }

  /** requests random number from chainlink */
  function performUpkeep(
    bytes calldata /* performData */
  ) external override {
    (bool upkeepNeeded, ) = checkUpkeep("");
    if (!upkeepNeeded) {
      revert Raffle__UpkeepNotNeeded(
        address(this).balance,
        s_players.length,
        uint256(s_raffleState)
      );
    }
    s_raffleState = RaffleState.CALCULATING;
    // request rand num
    // pick winner using the generated number
    // 2 transaction process to prevent manipulation
    uint256 requestId = i_vrfCoordinator.requestRandomWords(
      i_gasLane, // maximum gas price you are willing to pay for a request in wei
      i_subscriptionId, // for funding requests
      REQUEST_CONFIRMATIONS, // number of block confirmations to wait before responding
      i_callbackGasLimit, // limit of gas one is willing to use per request
      NUM_WORDS // number of random numbers to request
    );
    emit RequestedRaffleWinner(requestId);
  }

  /**
   * picks a random winner
   *
   * override = override a function defined in a parent
   */
  function fulfillRandomWords(
    uint256, /*requestId*/
    uint256[] memory randomWords
  ) internal override {
    uint256 indexOfWinner = randomWords[0] % s_players.length;
    address payable recentWinner = s_players[indexOfWinner];
    s_recentWinner = recentWinner;
    s_raffleState = RaffleState.OPEN;
    s_players = new address payable[](0);
    s_lastTimeStamp = block.timestamp;
    (bool success, ) = recentWinner.call{value: address(this).balance}("");
    if (!success) {
      revert Raffle__TransferFailed();
    }
    emit WinnerPicked(recentWinner);
  }

  /* view/pure functions */
  function getEntranceFee() public view returns (uint256) {
    return i_entranceFee;
  }

  function getPlayer(uint256 index) public view returns (address) {
    return s_players[index];
  }

  function getRecentWinner() public view returns (address) {
    return s_recentWinner;
  }

  function getRaffleState() public view returns (RaffleState) {
    return s_raffleState;
  }

  function getNumWords() public pure returns (uint32) {
    return NUM_WORDS;
  }

  function getNumberOfPlayers() public view returns (uint256) {
    return s_players.length;
  }

  function getLastTimeStamp() public view returns (uint256) {
    return s_lastTimeStamp;
  }

  function getRequestConfirmations() public pure returns (uint256) {
    return REQUEST_CONFIRMATIONS;
  }

  function getInterval() public view returns (uint256) {
    return i_interval;
  }
}
