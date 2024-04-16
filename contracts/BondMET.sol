// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

//  _____ ______   _______  _________  ___  ________  ___  ___  ___       ________  ___  ___  ________      
// |\   _ \  _   \|\  ___ \|\___   ___\\  \|\   ____\|\  \|\  \|\  \     |\   __  \|\  \|\  \|\   ____\     
// \ \  \\\__\ \  \ \   __/\|___ \  \_\ \  \ \  \___|\ \  \\\  \ \  \    \ \  \|\  \ \  \\\  \ \  \___|_    
//  \ \  \\|__| \  \ \  \_|/__  \ \  \ \ \  \ \  \    \ \  \\\  \ \  \    \ \  \\\  \ \  \\\  \ \_____  \   
//   \ \  \    \ \  \ \  \_|\ \  \ \  \ \ \  \ \  \____\ \  \\\  \ \  \____\ \  \\\  \ \  \\\  \|____|\  \  
//    \ \__\    \ \__\ \_______\  \ \__\ \ \__\ \_______\ \_______\ \_______\ \_______\ \_______\____\_\  \ 
//     \|__|     \|__|\|_______|   \|__|  \|__|\|_______|\|_______|\|_______|\|_______|\|_______|\_________\
//

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract BondMET is Ownable, ReentrancyGuard {
    IERC20 public usdc;
    IERC20 public met;

    uint256 public totalReferrals;
    address public topReferrer;

    mapping(string => address) public referralIdToAddress;
    mapping(address => uint256) public userReferrals;
    mapping(address => bool) public whitelisted;
    address[] public whitelist;

    mapping(address => uint256) public userContributions;

    uint256 public currentRound = 1;
    uint256 public currentRoundStartTimestamp;
    uint256 public currentRoundContributions;
    uint256 public bondingStartTimestamp;

    uint256 public totalContributions;

    bool public whitelistOnly;

    bool public BondingActive = false;

    uint256 constant MET_MIN_PRICE = 2_500; // 0.25 cents
    uint256 constant MET_MAX_PRICE = 5_000; // 0.5 cents
    uint256 constant ROUND_DURATION = 60 * 60 * 24; // 24 hours in seconds
    uint256 constant ROUND_MAX_CONTRIBUTION = 12_500 * 10 ** 6; // Maximum contribution of 5,000,000 MET in USDC (Note that USDC has 6 decimals)
    uint256 constant TOTAL_MAX_CONTRIBUTION = 437_500 * 10 ** 6; // Maximum total contribution of 175,000,000 MET in USDC (Note that USDC has 6 decimals)
    uint256 constant MINIMUM_CONTRIBUTION = 1 * 10 ** 6; // Minimum contribution is 1 USDC
    uint256 constant WHITELIST_ROUNDS = 2; // Whitelist only for the first 2 rounds

    /// contract controlled values
    uint64 public _endTime; // start time of the round + ROUND DURATION

    /// end contract controlled values
    constructor(IERC20 _usdc, IERC20 _met) {
        usdc = _usdc;
        met = _met;
    }

    function contribute(
        uint256 amount,
        string memory referralId
    ) public nonReentrant {
        require(BondingActive, "Bonding has not started yet");
        require(
            amount >= MINIMUM_CONTRIBUTION,
            "Contribution is less than minimum required"
        );
        require(
            usdc.transferFrom(msg.sender, owner(), amount),
            "Transfer of USDC failed"
        );
        try_new_day();

        // Check if whitelist round has ended
        if (
            whitelistOnly &&
            block.timestamp >
            bondingStartTimestamp + WHITELIST_ROUNDS * ROUND_DURATION
        ) {
            whitelistOnly = false;
        }

        if (whitelistOnly) {
            require(whitelisted[msg.sender], "Not allowed to contribute");
        }
        // Check if contribution limits have been reached
        require(
            currentRoundContributions + amount <= ROUND_MAX_CONTRIBUTION,
            "Round limit reached"
        );
        require(
            totalContributions + amount <= TOTAL_MAX_CONTRIBUTION,
            "Total contribution limit reached"
        );

        uint256 reward = (1e18 * amount) / current_price();
        require(met.transfer(msg.sender, reward), "Transfer of MET failed");
        /// Increase contributions
        currentRoundContributions += amount;
        totalContributions += amount;
        userContributions[msg.sender] += amount;

        // Generate unique ID for each contributor and map it to their address
        string memory contributorId = getReferralId(msg.sender);
        referralIdToAddress[contributorId] = msg.sender;

        if (bytes(referralId).length > 0) {
            address referrer = referralIdToAddress[referralId];
            require(referrer != address(0), "Referral ID is not valid");

            totalReferrals += 1;
            userReferrals[referrer] += amount;

            if (userReferrals[referrer] > userReferrals[topReferrer]) {
                topReferrer = referrer;
            }
        }
    }

    function try_new_day() internal {
        if (uint64(block.timestamp) > _endTime) {
            new_day();
        }
    }

    function new_day() internal {
        currentRoundContributions = 0;
        currentRoundStartTimestamp = block.timestamp;
        _endTime = uint64(ROUND_DURATION + block.timestamp);
    }

    /// @notice note that usdc being 1e6 decimals is hard coded here, since our price is in 6 decimals as well.
    function current_price() internal view returns (uint256) {
        // this is sold %, in 1e18 terms, multiplied by the difference between the start and max current_price
        // this will give us the amount to increase the price, in 1e18 terms
        uint256 scalar = ((currentRoundContributions * 1e18) /
            ROUND_MAX_CONTRIBUTION) * (MET_MAX_PRICE - MET_MIN_PRICE);
        // the price therefore is that number / 1e18 + the start price
        return (scalar / 1e18) + MET_MIN_PRICE;
    }

    function getCurrentRound() external view returns (uint256) {
        return currentRound;
    }

    function getCurrentPrice() external view returns (uint256) {
        return current_price();
    }

    function getTotalContributions() public view returns (uint256) {
        return totalContributions;
    }

    function getUserContributions(address user) public view returns (uint256) {
        return userContributions[user];
    }

    function whitelistWallet(address[] memory addresses) public onlyOwner {
        for (uint i = 0; i < addresses.length; i++) {
            whitelisted[addresses[i]] = true;
            whitelist.push(addresses[i]);
        }
    }

    function startBonding() public onlyOwner {
        BondingActive = true;
        whitelistOnly = true;
        currentRoundStartTimestamp = block.timestamp;
        bondingStartTimestamp = block.timestamp;
    }

    function getReferralId(address user) public pure returns (string memory) {
        string memory fullId = toAsciiString(user);
        string memory start = substring(fullId, 0, 5);
        string memory end = substring(fullId, 36, 40);
        return string(abi.encodePacked(start, end));
    }

    function toAsciiString(address x) internal pure returns (string memory) {
        bytes memory s = new bytes(40);
        for (uint i = 0; i < 20; i++) {
            bytes1 b = bytes1(uint8(uint(uint160(x)) / (2 ** (8 * (19 - i)))));
            bytes1 hi = bytes1(uint8(b) / 16);
            bytes1 lo = bytes1(uint8(b) - 16 * uint8(hi));
            s[2 * i] = char(hi);
            s[2 * i + 1] = char(lo);
        }
        return string(s);
    }

    function char(bytes1 b) internal pure returns (bytes1 c) {
        if (uint8(b) < 10) return bytes1(uint8(b) + 0x30);
        else return bytes1(uint8(b) + 0x57);
    }

    function substring(
        string memory str,
        uint startIndex,
        uint endIndex
    ) internal pure returns (string memory) {
        bytes memory strBytes = bytes(str);
        bytes memory result = new bytes(endIndex - startIndex);
        for (uint i = 0; i < endIndex - startIndex; i++) {
            result[i] = strBytes[i + startIndex];
        }
        return string(result);
    }

    function withdraw(uint256 _amount) external onlyOwner {
        met.transferFrom(address(this), msg.sender, _amount);
    }
}