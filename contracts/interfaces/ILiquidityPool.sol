// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

interface ILiquidityPool {
    struct Liquidity {
        // Amount of liquidity available for option collateral and premiums
        uint freeLiquidity;
        // Amount of liquidity available for withdrawals - different to freeLiquidity
        uint burnableLiquidity;
        // Amount of liquidity reserved for long options sold to traders
        uint reservedCollatLiquidity;
        // Portion of liquidity reserved for delta hedging (quote outstanding)
        uint pendingDeltaLiquidity;
        // Current value of delta hedge
        uint usedDeltaLiquidity;
        // Net asset value, including everything and netOptionValue
        uint NAV;
        // longs scaled down by this factor in a contract adjustment event
        uint longScaleFactor;
    }

    function getLiquidity() external view returns (Liquidity memory);
}
