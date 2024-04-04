// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@uniswap/v3-periphery/contracts/libraries/LiquidityAmounts.sol";

contract Compound is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    INonfungiblePositionManager public immutable nonfungiblePositionManager;
    ISwapRouter public immutable swapRouter;

    constructor(INonfungiblePositionManager _nonfungiblePositionManager, ISwapRouter _swapRouter) {
        nonfungiblePositionManager = _nonfungiblePositionManager;
        swapRouter = _swapRouter;
    }

    function collectAndReinvest(uint256 tokenId) external onlyOwner nonReentrant {
        INonfungiblePositionManager.CollectParams memory params = INonfungiblePositionManager.CollectParams({
            tokenId: tokenId,
            recipient: address(this), // Send the fees to this contract
            amount0Max: type(uint128).max,
            amount1Max: type(uint128).max
        });

        // Collect the fees from the position
        (uint256 amount0, uint256 amount1) = nonfungiblePositionManager.collect(params);

        // Re-invest the fees back into the pool
        if (amount0 > 0 || amount1 > 0) {
            _addLiquidity(tokenId, amount0, amount1);
        }
    }

    function _addLiquidity(uint256 tokenId, uint256 amount0, uint256 amount1) private {
        // Approve the position manager to spend the tokens
        IERC20 token0 = IERC20(nonfungiblePositionManager.positions(tokenId).token0);
        IERC20 token1 = IERC20(nonfungiblePositionManager.positions(tokenId).token1);

        token0.safeApprove(address(nonfungiblePositionManager), amount0);
        token1.safeApprove(address(nonfungiblePositionManager), amount1);

        INonfungiblePositionManager.IncreaseLiquidityParams memory increaseParams = INonfungiblePositionManager.IncreaseLiquidityParams({
            tokenId: tokenId,
            amount0Desired: amount0,
            amount1Desired: amount1,
            amount0Min: 0,
            amount1Min: 0,
            deadline: block.timestamp
        });

        // Increase liquidity
        nonfungiblePositionManager.increaseLiquidity(increaseParams);

        // Reset approval
        token0.safeApprove(address(nonfungiblePositionManager), 0);
        token1.safeApprove(address(nonfungiblePositionManager), 0);
    }
    
    // ... Additional contract functions and logic ...
}
