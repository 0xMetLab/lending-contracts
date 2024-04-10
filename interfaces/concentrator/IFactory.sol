// SPDX-License-Identifier: SAL-1.0
pragma solidity 0.8.12;

interface IFactory {
    function underlyingV3Factory() external view returns (address);

    function platformFeesVault() external view returns (address);

    function dispatcher() external view returns (address);

    function createMultipool(
        address token0,
        address token1,
        uint24[] memory fees,
        string memory tokens
    ) external returns (address);

    function getmultipool(address token0, address token1) external view returns (address);

    function getAmountOut(
        uint24 poolFee,
        uint128 amountIn,
        address tokenIn,
        address tokenOut
    ) external view returns (uint256 amountOut);

    function estimateWithdrawalAmounts(
        address tokenA,
        address tokenB,
        uint256 lpAmount
    ) external view returns (uint256 amount0, uint256 amount1);

    function estimateDepositAmounts(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired
    ) external view returns (uint256 amountA, uint256 amountB, uint256 lpAmount);
}