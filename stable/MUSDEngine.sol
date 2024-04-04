// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

//  _________  ________  ________  ________  ___  ___  _______      
// |\___   ___\\   __  \|\   __  \|\   __  \|\  \|\  \|\  ___ \     
// \|___ \  \_\ \  \|\  \ \  \|\  \ \  \|\  \ \  \\\  \ \   __/|    
//     \ \  \ \ \  \\\  \ \   _  _\ \  \\\  \ \  \\\  \ \  \_|/__  
//      \ \  \ \ \  \\\  \ \  \\  \\ \  \\\  \ \  \\\  \ \  \_|\ \ 
//       \ \__\ \ \_______\ \__\\ _\\ \_____  \ \_______\ \_______\
//        \|__|  \|_______|\|__|\|__|\|___| \__\|_______|\|_______|

import "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {OracleLib, AggregatorV3Interface} from "./libraries/OracleLib.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MUSD} from "./MUSD.sol";

contract MUSDEngine is Ownable, ReentrancyGuard {

    error MUSDEngine__NeedsMoreThanZero();
    error MUSDEngine__BreaksHealthFactor(uint256 healthFactorValue);
    error MUSDEngine__MintFailed();
    error MUSDEngine__HealthFactorOk();
    error MUSDEngine__HealthFactorNotImproved();

    using OracleLib for AggregatorV3Interface;

    MUSD public immutable i_MUSD; 
    IERC20 public immutable wbtcToken; 
    AggregatorV3Interface public immutable wbtcPriceFeed;

    uint256 private constant LIQUIDATION_THRESHOLD = 98;
    uint256 private constant LIQUIDATION_BONUS = 20;
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant MIN_HEALTH_FACTOR = 1e18;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 private constant FEED_PRECISION = 1e8;
    uint256 private constant WBTC_DECIMAL = 1e8;

    mapping(address => uint256) private s_collateralDeposited;
    mapping(address => uint256) private s_MUSDMinted;
    
    address public treasuryAddress;

    event CollateralDeposited(address indexed user, uint256 amount);
    event CollateralRedeemed(address indexed from, address indexed to, uint256 amount);
    event MUSDMinted(address indexed user, uint256 amount);
    event MUSDBurned(address indexed user, uint256 amount);

    modifier moreThanZero(uint256 amount) {
        require(amount > 0, "Amount must be more than zero");
        _;
    }

    constructor(address wbtcTokenAddress, address wbtcPriceFeedAddress, address MUSDAddress) Ownable(msg.sender) {
        i_MUSD = MUSD(MUSDAddress);
        wbtcToken = IERC20(wbtcTokenAddress);
        wbtcPriceFeed = AggregatorV3Interface(wbtcPriceFeedAddress);
    }

    function depositCollateralAndMintMUSD(uint256 amountCollateral, uint256 amountMUSDToMint) external moreThanZero(amountCollateral) {
        depositCollateral(amountCollateral);
        mintMUSD(amountMUSDToMint);
    }

    function redeemCollateralForMUSD(uint256 amountCollateral, uint256 amountMUSDToBurn) external moreThanZero(amountCollateral) {
        _burnMUSD(amountMUSDToBurn, msg.sender, msg.sender);
        _redeemCollateral(amountCollateral, msg.sender, msg.sender);
        revertIfHealthFactorIsBroken(msg.sender);
    }

    function depositCollateral(uint256 amountCollateral) public moreThanZero(amountCollateral) nonReentrant {
        s_collateralDeposited[msg.sender] += amountCollateral;
        require(wbtcToken.transferFrom(msg.sender, address(this), amountCollateral), "Transfer failed");
        emit CollateralDeposited(msg.sender, amountCollateral);
    }

    function redeemCollateral(uint256 amountCollateral) external moreThanZero(amountCollateral) nonReentrant {
        _redeemCollateral(amountCollateral, msg.sender, msg.sender);
        revertIfHealthFactorIsBroken(msg.sender);
    }

    function mintMUSD(uint256 amountMUSDToMint) public moreThanZero(amountMUSDToMint) nonReentrant {
        s_MUSDMinted[msg.sender] += amountMUSDToMint;
        revertIfHealthFactorIsBroken(msg.sender);
        require(i_MUSD.mint(msg.sender, amountMUSDToMint), "Mint failed");
        emit MUSDMinted(msg.sender, amountMUSDToMint);
    }
    
    function burnMUSD(uint256 amount) external moreThanZero(amount) {
        _burnMUSD(amount, msg.sender, msg.sender);
        revertIfHealthFactorIsBroken(msg.sender);
    }

    function liquidate(address user, uint256 debtToCover) external moreThanZero(debtToCover) nonReentrant {
        uint256 startingUserHealthFactor = _healthFactor(user);
        if (startingUserHealthFactor >= MIN_HEALTH_FACTOR) {
            revert MUSDEngine__HealthFactorOk();
        }
        uint256 tokenAmountFromDebtCovered = getTokenAmountFromUsd(debtToCover);
        uint256 bonusCollateral = (tokenAmountFromDebtCovered * LIQUIDATION_BONUS) / 100;
        _redeemCollateral(tokenAmountFromDebtCovered + bonusCollateral, user, msg.sender);
        _burnMUSD(debtToCover, user, msg.sender);
        uint256 endingUserHealthFactor = _healthFactor(user);
        if (endingUserHealthFactor <= startingUserHealthFactor) {
            revert MUSDEngine__HealthFactorNotImproved();
        }
        revertIfHealthFactorIsBroken(msg.sender);
    }

    function setTreasuryAddress(address _treasuryAddress) external onlyOwner {
        require(_treasuryAddress != address(0), "Invalid treasury address");
        treasuryAddress = _treasuryAddress;
    }

    function deployReserves(uint256 amount) external onlyOwner nonReentrant {
        require(amount > 0, "Amount must be greater than zero");
        require(wbtcToken.balanceOf(address(this)) >= amount, "Insufficient balance");
        require(wbtcToken.transfer(treasuryAddress, amount), "Transfer failed");
    }

    function _redeemCollateral(uint256 amountCollateral, address from, address to) private {
        require(s_collateralDeposited[from] >= amountCollateral, "Insufficient collateral");
        s_collateralDeposited[from] -= amountCollateral;
        require(wbtcToken.transfer(to, amountCollateral), "Transfer failed");
        emit CollateralRedeemed(address(this), to, amountCollateral);
    }

    function _burnMUSD(uint256 amountMUSDToBurn, address onBehalfOf, address MUSDFrom) private {
        require(s_MUSDMinted[onBehalfOf] >= amountMUSDToBurn, "Insufficient MUSD balance");
        s_MUSDMinted[onBehalfOf] -= amountMUSDToBurn;
        require(i_MUSD.transferFrom(MUSDFrom, address(this), amountMUSDToBurn), "Transfer failed");
        i_MUSD.burn(amountMUSDToBurn);
        emit MUSDBurned(onBehalfOf, amountMUSDToBurn);
    }

    function _getAccountInformation(address user) private view returns (uint256 totalMUSDMinted, uint256 collateralValueInUsd) {
        totalMUSDMinted = s_MUSDMinted[user];
        collateralValueInUsd = getAccountCollateralValue(user);
        return (totalMUSDMinted, collateralValueInUsd);
    }

    function _healthFactor(address user) private view returns (uint256) {
        (uint256 totalMUSDMinted, uint256 collateralValueInUsd) = _getAccountInformation(user);
        return _calculateHealthFactor(totalMUSDMinted, collateralValueInUsd);
    }

    function _geMUSDValue(uint256 amount) private view returns (uint256) {
        (, int256 price,,,) = wbtcPriceFeed.latestRoundData();
        return (uint256(price) * amount * PRECISION) / (FEED_PRECISION*wbtc_DECIMAL);
    }

    function _calculateHealthFactor(uint256 totalMUSDMinted, uint256 collateralValueInUsd) internal pure returns (uint256) {
        if (totalMUSDMinted == 0) return type(uint256).max;
        uint256 collateralAdjustedForThreshold = (collateralValueInUsd * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;
        return (collateralAdjustedForThreshold * PRECISION) / totalMUSDMinted;
    }

    function revertIfHealthFactorIsBroken(address user) internal view {
        require(_healthFactor(user) >= MIN_HEALTH_FACTOR, "Health factor broken");
    }

    function calculateHealthFactor(uint256 totalMUSDMinted, uint256 collateralValueInUsd) external pure returns (uint256) {
        return _calculateHealthFactor(totalMUSDMinted, collateralValueInUsd);
    }

    function getAccountInformation(address user) external view returns (uint256 totalMUSDMinted, uint256 collateralValueInUsd) {
        return _getAccountInformation(user);
    }

    function geMUSDValue(uint256 amount) external view returns (uint256) {
        return _geMUSDValue(amount);
    }

    function getCollateralBalanceOfUser(address user) external view returns (uint256) {
        return s_collateralDeposited[user];
    }

    function getAccountCollateralValue(address user) public view returns (uint256 totalCollateralValueInUsd) {
        uint256 amountCollateral = s_collateralDeposited[user];
        return _geMUSDValue(amountCollateral);
    }

    function getTokenAmountFromUsd(uint256 usdAmountInWei) public view returns (uint256) {
        (, int256 price,,,) = wbtcPriceFeed.staleCheckLatestRoundData();
        return ((usdAmountInWei * PRECISION) / (uint256(price) * ADDITIONAL_FEED_PRECISION));
    }

    function getPrecision() external pure returns (uint256) {
        return PRECISION;
    }

    function getAdditionalFeedPrecision() external pure returns (uint256) {
        return ADDITIONAL_FEED_PRECISION;
    }

    function getLiquidationThreshold() external pure returns (uint256) {
        return LIQUIDATION_THRESHOLD;
    }

    function getLiquidationBonus() external pure returns (uint256) {
        return LIQUIDATION_BONUS;
    }

    function getLiquidationPrecision() external pure returns (uint256) {
        return LIQUIDATION_PRECISION;
    }

    function getMinHealthFactor() external pure returns (uint256) {
        return MIN_HEALTH_FACTOR;
    }

    function getMUSD() external view returns (address) {
        return address(i_MUSD);
    }

    function getHealthFactor(address user) external view returns (uint256) {
        return _healthFactor(user);
    }
}
