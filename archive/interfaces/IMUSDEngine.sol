// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

//  _____ ______   _______  _________  ___  ________  ___  ___  ___       ________  ___  ___  ________      
// |\   _ \  _   \|\  ___ \|\___   ___\\  \|\   ____\|\  \|\  \|\  \     |\   __  \|\  \|\  \|\   ____\     
// \ \  \\\__\ \  \ \   __/\|___ \  \_\ \  \ \  \___|\ \  \\\  \ \  \    \ \  \|\  \ \  \\\  \ \  \___|_    
//  \ \  \\|__| \  \ \  \_|/__  \ \  \ \ \  \ \  \    \ \  \\\  \ \  \    \ \  \\\  \ \  \\\  \ \_____  \   
//   \ \  \    \ \  \ \  \_|\ \  \ \  \ \ \  \ \  \____\ \  \\\  \ \  \____\ \  \\\  \ \  \\\  \|____|\  \  
//    \ \__\    \ \__\ \_______\  \ \__\ \ \__\ \_______\ \_______\ \_______\ \_______\ \_______\____\_\  \ 
//     \|__|     \|__|\|_______|   \|__|  \|__|\|_______|\|_______|\|_______|\|_______|\|_______|\_________\
//    

interface ITUSDEngine {
    function getMintableTUSD(address user, uint256 amountCollateral) external view returns (uint256, bool);
    function getBurnableTUSD(address user, uint256 amountTUSD) external view returns (uint256, bool);
    function getAccountInformation(address user) external view returns (uint256 totalTusdMinted, uint256 collateralValueInUsd);
    function getPrecision() external pure returns (uint256);
    function getLiquidationPrecision() external pure returns (uint256);
    function getLiquidationThreshold() external pure returns (uint256);
    function getMinHealthFactor() external pure returns (uint256);
    function depositCollateralAndMintTusd(uint256 amountCollateral, uint256 amountTusdToMint) external;
    function redeemCollateralForTusd(uint256 amountCollateral, uint256 amountTusdToBurn) external ;
    function getCollateralBalanceOfUser(address user) external view returns (uint256);
    function mintTusd(uint256 amountTusdToMint) external;
}
