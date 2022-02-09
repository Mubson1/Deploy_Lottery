// SPDX-License-Identifier: MIT
pragma solidity ^0.6.6;

import "@chainlink/contracts/src/v0.6/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.6/VRFConsumerBase.sol";

/*
    This above VRFConumerBase.sol is imported to get a random number and it calles the following .sol file:
*/

// pragma solidity ^0.8.7;

// import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";

// /**
//  * THIS IS AN EXAMPLE CONTRACT WHICH USES HARDCODED VALUES FOR CLARITY.
//  * PLEASE DO NOT USE THIS CODE IN PRODUCTION.
//  */

// /**
//  * Request testnet LINK and ETH here: https://faucets.chain.link/
//  * Find information on LINK Token Contracts and get the latest ETH and LINK faucets here: https://docs.chain.link/docs/link-token-contracts/
//  */

// contract RandomNumberConsumer is VRFConsumerBase {

//     bytes32 internal keyHash;
//     uint256 internal fee;

//     uint256 public randomResult;

//     /**
//      * Constructor inherits VRFConsumerBase
//      *
//      * Network: Kovan
//      * Chainlink VRF Coordinator address: 0xdD3782915140c8f3b190B5D67eAc6dc5760C46E9
//      * LINK token address:                0xa36085F69e2889c224210F603D836748e7dC0088
//      * Key Hash: 0x6c3699283bda56ad74f6b855546325b68d482e983852a7a82979cc4807b641f4
//      */
//     constructor()
//         VRFConsumerBase(
//             0xdD3782915140c8f3b190B5D67eAc6dc5760C46E9, // VRF Coordinator
//             0xa36085F69e2889c224210F603D836748e7dC0088  // LINK Token
//         )
//     {
//         keyHash = 0x6c3699283bda56ad74f6b855546325b68d482e983852a7a82979cc4807b641f4;
//         fee = 0.1 * 10 ** 18; // 0.1 LINK (Varies by network)
//     }

//     /**
//      * Requests randomness
//      */
//     function getRandomNumber() public returns (bytes32 requestId) {
//         require(LINK.balanceOf(address(this)) >= fee, "Not enough LINK - fill contract with faucet");
//         return requestRandomness(keyHash, fee);
//     }

//     /**
//      * Callback function used by VRF Coordinator
//      */
//     function fulfillRandomness(bytes32 requestId, uint256 randomness) internal override {
//         randomResult = randomness;
//     }

//     // function withdrawLink() external {} - Implement a withdraw function to avoid locking your LINK in the contract
// }

//Here, ownable is used to know who deployed the contract
contract Lottery is VRFConsumerBase, Ownable {
    //This players list contains the details of players who have entered the lottery
    address payable[] public players;
    address payable public recentWinner;
    uint256 public randomness;
    uint256 public usdEntryFee;
    AggregatorV3Interface internal ethUsdPriceFeed;
    //Here, if a user do not give enough eth, then they cannot get buy lottery. But, after the require in enter(), the contract may end if the condition is not satisfied. But remember that there are other functions like start and end lottery which is independent of what the user provides. Thus, they should be executed. So, we use enum for this
    enum LOTTERY_STATE {
        OPEN,
        CLOSED,
        CALCULATING_WINNER
    }
    LOTTERY_STATE public lottery_state;
    //These are the variables that are needed for generating random no. in endlottery() function and varies for each contract. So, they are set in the constructor
    uint256 public fee;
    bytes32 public keyhash;
    event RequestedRandomness(bytes32 requestId);

    // 0
    // 1
    // 2

    //A constructor of VRFConsumerBase is initialized/ called from the constructor of this contract
    constructor(
        address _priceFeedAddress,
        address _vrfCoordinator,
        address _link,
        uint256 _fee,
        bytes32 _keyhash
    ) public VRFConsumerBase(_vrfCoordinator, _link) {
        usdEntryFee = 50 * (10**18);
        ethUsdPriceFeed = AggregatorV3Interface(_priceFeedAddress);
        //When the lottery is initialized, lottery_state is set closed. This means unless, the lottery only starts when the start function is called. At the beginning, the lottery is closed.
        lottery_state = LOTTERY_STATE.CLOSED;
        fee = _fee;
        keyhash = _keyhash;
    }

    function enter() public payable {
        // $50 minimum
        require(lottery_state == LOTTERY_STATE.OPEN);
        require(msg.value >= getEntranceFee(), "Not enough ETH!");
        players.push(msg.sender);
    }

    function getEntranceFee() public view returns (uint256) {
        /* This is a function that is called by above import of @chainlink. You can find this by searching chainlink latest price
        function getLatestPrice() public view returns (int) {
            (
                uint80 roundID, 
                int price,
                uint startedAt,
                uint timeStamp,
                uint80 answeredInRound
            ) = priceFeed.latestRoundData();
            return price;
        }
        */
        //So, there are five returns and we want price at the first index of list
        (, int256 price, , , ) = ethUsdPriceFeed.latestRoundData();
        //The price that is obtained from the above contains 8 decimals. So, we need to multiply it by 10**10 to equal 10*18
        uint256 adjustedPrice = uint256(price) * 10**10;
        //Observe that the usdEntryFee is alread multiplied by 10*18 in constructor. So, the below code would give very large value of costToEnter. But it is okay since that will be cancelled out by the above adjusted price of 10**10
        uint256 costToEnter = (usdEntryFee * 10**18) / adjustedPrice;
        return costToEnter;
    }

    //onlyOwner lets only the contract deployer to call the function
    function startLottery() public onlyOwner {
        require(
            lottery_state == LOTTERY_STATE.CLOSED,
            "Can't start a new lottery yet!"
        );
        lottery_state = LOTTERY_STATE.OPEN;
    }

    //In this transaction, we are going to request the data from chainlink oracle. Then, in another transaction, chainlink node is going to return the data to this contract using fullfillrandomness() function
    function endLottery() public onlyOwner {
        /*
            This is a way of getting randomness. Remember that absolute randomness cannot be achieved. So, commented code is very risky and should be avoided.
        */
        // uint256(
        //     keccack256(
        //         abi.encodePacked(
        //             nonce, // nonce is preditable (aka, transaction number)
        //             msg.sender, // msg.sender is predictable
        //             block.difficulty, // can actually be manipulated by the miners!
        //             block.timestamp // timestamp is predictable
        //         )
        //     )
        // ) % players.length;

        lottery_state = LOTTERY_STATE.CALCULATING_WINNER;
        //This will functino will return a requestID in bytes32 format
        bytes32 requestId = requestRandomness(keyhash, fee);
        emit RequestedRandomness(requestId);
    }

    //This is the second transaction. Here, only the VRFCoordinator can be able to call this function so, internal is used.
    //Also, override is used. Our imported VRFConsumerBase already have this fullfillRandomness() funcion which is created to be overriden by our code or simply, this function in the VRFConsumerBase is empty.
    function fulfillRandomness(bytes32 _requestId, uint256 _randomness)
        internal
        override
    {
        require(
            lottery_state == LOTTERY_STATE.CALCULATING_WINNER,
            "You aren't there yet!"
        );
        require(_randomness > 0, "random-not-found");
        //Here, %  returns the remainder after _randomness is divided by players.length. This remainder becomes the random index that defines the latest winner of this contract.
        uint256 indexOfWinner = _randomness % players.length;
        recentWinner = players[indexOfWinner];
        //Now, once the winner is set, he/she will get all the money that has been gathered when players executed entry() function for entering the lottery.
        recentWinner.transfer(address(this).balance);
        //Now, we have to reset the lottery so that it can be started again.
        players = new address payable[](0);
        lottery_state = LOTTERY_STATE.CLOSED;
        randomness = _randomness;
    }
}
