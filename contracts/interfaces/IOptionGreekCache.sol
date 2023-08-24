// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

interface IOptionGreekCache {
    struct StrikeGreeks {
        int callDelta;
        int putDelta;
        uint stdVega;
        uint callPrice;
        uint putPrice;
    }

    struct NetGreeks {
        int netDelta;
        int netStdVega;
        int netOptionValue;
    }

    struct TradePricing {
        uint optionPrice;
        int preTradeAmmNetStdVega;
        int postTradeAmmNetStdVega;
        int callDelta;
        uint volTraded;
        uint ivVariance;
        uint vega;
    }

    struct StrikeCache {
        uint id;
        uint boardId;
        uint strikePrice;
        uint skew;
        StrikeGreeks greeks;
        int callExposure; // long - short
        int putExposure; // long - short
        uint skewVariance; // (GWAVSkew - skew)
    }

    struct OptionBoardCache {
        uint id;
        uint[] strikes;
        uint expiry;
        uint iv;
        NetGreeks netGreeks;
        uint updatedAt;
        uint updatedAtPrice;
        uint maxSkewVariance;
        uint ivVariance;
    }

    struct GlobalCache {
        uint minUpdatedAt;
        uint minUpdatedAtPrice;
        uint maxUpdatedAtPrice;
        uint maxSkewVariance;
        uint maxIvVariance;
        NetGreeks netGreeks;
    }

    function getStrikeCache(uint strikeId) external view returns (StrikeCache memory); 
    function getOptionBoardCache(uint boardId) external view returns (OptionBoardCache memory); 
    function getGlobalCache() external view returns (GlobalCache memory);
}