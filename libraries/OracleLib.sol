// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

//  _____ ______   _______  _________  ___  ________  ___  ___  ___       ________  ___  ___  ________      
// |\   _ \  _   \|\  ___ \|\___   ___\\  \|\   ____\|\  \|\  \|\  \     |\   __  \|\  \|\  \|\   ____\     
// \ \  \\\__\ \  \ \   __/\|___ \  \_\ \  \ \  \___|\ \  \\\  \ \  \    \ \  \|\  \ \  \\\  \ \  \___|_    
//  \ \  \\|__| \  \ \  \_|/__  \ \  \ \ \  \ \  \    \ \  \\\  \ \  \    \ \  \\\  \ \  \\\  \ \_____  \   
//   \ \  \    \ \  \ \  \_|\ \  \ \  \ \ \  \ \  \____\ \  \\\  \ \  \____\ \  \\\  \ \  \\\  \|____|\  \  
//    \ \__\    \ \__\ \_______\  \ \__\ \ \__\ \_______\ \_______\ \_______\ \_______\ \_______\____\_\  \ 
//     \|__|     \|__|\|_______|   \|__|  \|__|\|_______|\|_______|\|_______|\|_______|\|_______|\_________\
//      

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

library OracleLib {
    error OracleLib__StalePrice();

    uint256 private constant TIMEOUT = 3 hours;

    function staleCheckLatestRoundData(AggregatorV3Interface chainlinkFeed)
        internal
        view
        returns (uint80, int256, uint256, uint256, uint80)
    {
        (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) =
            chainlinkFeed.latestRoundData();

        if (updatedAt == 0 || answeredInRound < roundId) {
            revert OracleLib__StalePrice();
        }
        uint256 secondsSince = block.timestamp - updatedAt;
        if (secondsSince > TIMEOUT) revert OracleLib__StalePrice();

        return (roundId, answer, startedAt, updatedAt, answeredInRound);
    }

    function getTimeout(AggregatorV3Interface /* chainlinkFeed */ ) internal pure returns (uint256) {
        return TIMEOUT;
    }
}
