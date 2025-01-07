// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;
import {AutomationCompatibleInterface} from "@chainlink/contracts/src/v0.8/automation/AutomationCompatible.sol";

contract MinimalDraw is AutomationCompatibleInterface {
    address public admin;
    address public s_forwarderAddress; // Forwarder address
    address[] public participants;
    uint256 ticketprice = 100000000000000; // 0.0001 ETH in wei
    address public winner;
    uint256 public maxTickets = 10;
    uint256 public lotteryEndTime;
    bool public drawActive;

    event TicketPurchased(address indexed participant);
    event WinnerSelected(address indexed winner);
    
    // constructor
    constructor() {
        admin = msg.sender;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "Not Authorized");
        _;
    }

    modifier onlyAdminOrForwarder() {
        require(msg.sender == admin || msg.sender == s_forwarderAddress, "Not Authorized");
        _;
    }

    modifier lotteryClosed() {
        require(block.timestamp >= lotteryEndTime, "Lottery is still ongoing");
        _;
    }

    function setForwarderAddress(address forwarderAddress) external onlyAdmin {
        s_forwarderAddress = forwarderAddress;
    }

    function startLottery() internal {
        lotteryEndTime = block.timestamp + 60; // 60 seconds = 1 minute
        drawActive = true;
    }

    function buyTicket() public payable {
        require(msg.value == ticketprice, "Incorrect ticket price");
        require(participants.length < maxTickets, "All tickets sold");
        if (participants.length == 0) {
            startLottery(); // Start the lottery when the first ticket is purchased
        }
        participants.push(msg.sender);
        emit TicketPurchased(msg.sender);
    }

    function winnerAnnounce() public onlyAdminOrForwarder lotteryClosed {
        require(participants.length > 0, "No participants");

        uint256 randomIndex = uint256(
            keccak256(
                abi.encodePacked(
                    block.timestamp,
                    block.difficulty,
                    participants.length
                )
            )
        ) % participants.length;

        winner = participants[randomIndex];
        uint256 prize = (address(this).balance * 90) / 100;
        payable(winner).transfer(prize); // 90% to winner account
        payable(admin).transfer(address(this).balance); // Remaining 10% to admin
        emit WinnerSelected(winner);

        // Reset draw
        delete participants;
        lotteryEndTime = 0;
        drawActive = false;
    }

    // Chainlink Keepers methods
    function checkUpkeep(
        bytes calldata /* checkData */
    ) external view override returns (bool upkeepNeeded, bytes memory performData) {
        upkeepNeeded = (block.timestamp >= lotteryEndTime && drawActive && participants.length > 0);
        performData = "";
        return (upkeepNeeded, performData);
    }

    function performUpkeep(bytes calldata /* performData */) external override {
        if (
            block.timestamp >= lotteryEndTime &&
            drawActive &&
            participants.length > 0
        ) {
            winnerAnnounce();
        }
    }
}
