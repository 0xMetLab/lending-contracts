// SPDX-License-Identifier: SAL-1.0
pragma solidity 0.8.12;

struct Slot0Data {
    int24 tick;
    uint160 currentSqrtRatioX96;
}

struct PositionInfo {
    int24 lowerTick;
    int24 upperTick;
    uint24 poolFeeAmt;
    uint256 weight;
    address poolAddress;
    bytes32 positionKey;
}

struct UnderlyingPool {
    int24 tickSpacing;
    address poolAddress;
}
struct FeeGrowth {
    uint256 accPerShare0;
    uint256 accPerShare1;
    uint256 protocolAccPerShare0;
    uint256 protocolAccPerShare1;
}

struct ProtocolFees {
    uint256 amount0;
    uint256 amount1;
}

interface IMultipool {
    function snapshot()
        external
        returns (
            uint256 reserve0,
            uint256 reserve1,
            FeeGrowth memory feesGrow,
            uint256 _totalSupply
        );

    function multiPosition(uint256 indx) external view returns (PositionInfo memory);

    function getFeesLength() external view returns (uint256);

    function getMultiPositionLength() external view returns (uint256);

    function earn() external;

    function getTimeWeightedAmountOut(
        bool zeroForOne,
        uint256 amountIn
    ) external view returns (uint256 swappedOut);

    function feesGrowthInsideLastX128() external view returns (FeeGrowth memory);

    function protocolFeeWeight() external view returns (uint256);

    function protocolFees() external view returns (ProtocolFees memory);

    function underlyingTrustedPools(uint24 fee) external view returns (UnderlyingPool memory);

    function getReserves()
        external
        view
        returns (uint256 reserve0, uint256 reserve1, uint256 pendingFee0, uint256 pendingFee1);

    function multipoolToken() external view returns (address);

    function token0() external view returns (address);

    function token1() external view returns (address);

    function claimProtocolFees() external;

    function withdraw(
        uint256 lpAmount,
        uint256 amount0OutMin,
        uint256 amount1OutMin,
        address recipient
    ) external returns (uint256 withdrawnAmount0, uint256 withdrawnAmount1);

    function deposit(
        uint256 amount0Desired,
        uint256 amount1Desired,
        uint256 amount0Min,
        uint256 amount1Min,
        address recipient
    ) external returns (uint256 lpAmount);
}
