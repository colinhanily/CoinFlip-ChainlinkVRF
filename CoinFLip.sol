pragma solidity ^0.8.0;

import "https://github.com/smartcontractkit/chainlink/blob/558f42f5122779cb2e05dc8c2b84d1ae78cc0d71/contracts/src/v0.8/dev/VRFConsumerBase.sol";

contract CoinFlipFactory {
    address[] public deployedCoinFlips;

    function createCoinFlip(uint minimum) public {
        address newCoinFlip = address(new CoinFlip(minimum, msg.sender));
        deployedCoinFlips.push(newCoinFlip);
    }

    function getDeployedCoinFlips() public view returns (address[] memory){
        return deployedCoinFlips;
    }
}

contract CoinFlip is VRFConsumerBase {

    bytes32 internal keyHash;
    uint256 internal fee;
    uint256 public createTime;

    struct status {
        uint side; // 1=Heads, 2=Tails
        bool isWinner;
        bool gotWinnings;
    }

    address public CoinFlipCreator;
    mapping (address => status) public playerStatus;
    uint256 public contribution;
    uint256 public numHeads;
    uint256 public numTails;
    uint256 public winningSide;
    uint256 public weiPerWinner;
    uint256 private constant NOT_STARTED = 41;
    uint256 private constant ROLL_IN_PROGRESS = 42;
    uint256 private constant COMPLETED = 43;
    uint256 public CoinFlipStatus = NOT_STARTED;

    event SidePickStarted(bytes32 indexed requestId);
    event SidePicked(bytes32 indexed requestId);

    constructor(uint minumum, address creator) VRFConsumerBase(0xb3dCcb4Cf7a26f6cf6B120Cf5A73875B7BBc655B, // Rinkeby VRF Coordinator
                                                               0x01BE23585060835E02B77ef475b0Cc51aA1e0709  // Rinkeby LINK Token
                                                              )
    {
        keyHash = 0x2ed0feb3e7fd2022120aa84fab1945545a9f2ffc9076fd6156fa96eaff4c1311;
        fee = 0.1 * 10 ** 18; // 0.1 LINK
        createTime = block.timestamp;
        contribution = minumum;
        CoinFlipCreator = creator;
    }

    function flipCoin() public returns (bytes32 requestId) {
        require(CoinFlipStatus == NOT_STARTED, "CoinFlip already started");
        require(address(this).balance >= 100 wei, "Start conditions not met");
        require(LINK.balanceOf(address(this)) >= fee, "Not enough LINK");
        requestId = requestRandomness(keyHash, fee);
        CoinFlipStatus = ROLL_IN_PROGRESS;
        emit SidePickStarted(requestId);
    }

    function fulfillRandomness(bytes32 requestId, uint256 randomness) internal override {
        winningSide = randomness % 2 + 1;

        if (winningSide == 1) {
            weiPerWinner = address(this).balance / numHeads;
        } else {
          weiPerWinner = address(this).balance / numTails;
        }
        emit SidePicked(requestId);
        CoinFlipStatus = COMPLETED;
    }

    function enterHeads() public payable {
        require(msg.value == contribution, "Invalid entry amount");
        require(CoinFlipStatus == NOT_STARTED, "CoinFlip already started");
        require(playerStatus[msg.sender].side == 0, "Player already entered");
        playerStatus[msg.sender].side = 1;
        numHeads++;
    }

    function enterTails() public payable {
        require(msg.value == contribution, "Invalid entry amount");
        require(CoinFlipStatus == NOT_STARTED, "CoinFlip already started");
        require(playerStatus[msg.sender].side == 0, "Player already entered");
        playerStatus[msg.sender].side = 2;
        numTails++;
    }

    function withdrawHeads() public payable {
        require(CoinFlipStatus == NOT_STARTED, "CoinFlip already started");
        require(playerStatus[msg.sender].side == 1, "Player not entered");
        playerStatus[msg.sender].side = 0;
        payable(msg.sender).transfer(contribution);
        numHeads--;
    }

    function withdrawTails() public payable {
        require(CoinFlipStatus == NOT_STARTED, "CoinFlip already started");
        require(playerStatus[msg.sender].side == 2, "Player not entered");
        playerStatus[msg.sender].side = 0;
        payable(msg.sender).transfer(contribution);
        numTails--;
    }

    function getWinnings() public {
        require(playerStatus[msg.sender].gotWinnings == false);
        require(CoinFlipStatus == COMPLETED);
        require(playerStatus[msg.sender].side == winningSide);
        playerStatus[msg.sender].gotWinnings = true;
        payable(msg.sender).transfer(weiPerWinner);
    }
}
