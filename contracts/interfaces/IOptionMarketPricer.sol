// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import "./IOptionMarket.sol";
import "./IOptionGreekCache.sol";

interface IOptionMarketPricer {
    struct VegaUtilFeeComponents {
        int preTradeAmmNetStdVega;
        int postTradeAmmNetStdVega;
        uint vegaUtil;
        uint volTraded;
        uint NAV;
        uint vegaUtilFee;
    }

    struct PricingParameters {
        // Percentage of option price that is charged as a fee
        uint optionPriceFeeCoefficient;
        // Refer to: getTimeWeightedFee()
        uint optionPriceFee1xPoint;
        uint optionPriceFee2xPoint;
        // Percentage of spot price that is charged as a fee per option
        uint spotPriceFeeCoefficient;
        // Refer to: getTimeWeightedFee()
        uint spotPriceFee1xPoint;
        uint spotPriceFee2xPoint;
        // Refer to: getVegaUtilFee()
        uint vegaFeeCoefficient;
        // The amount of options traded to move baseIv for the board up or down 1 point (depending on trade direction)
        uint standardSize;
        // The relative move of skew for a given strike based on standard sizes traded
        uint skewAdjustmentFactor;
    }

    struct VarianceFeeComponents {
        uint varianceFeeCoefficient;
        uint vega;
        uint vegaCoefficient;
        uint skew;
        uint skewCoefficient;
        uint ivVariance;
        uint ivVarianceCoefficient;
        uint varianceFee;
    }

    function getVegaUtilFee(
        IOptionMarket.TradeParameters memory trade,
        IOptionGreekCache.TradePricing memory pricing
    ) external view returns (VegaUtilFeeComponents memory vegaUtilFeeComponents);

    function getTimeWeightedFee(
        uint expiry,
        uint pointA,
        uint pointB,
        uint coefficient
    ) external view returns (uint timeWeightedFee);

    function getVarianceFee(
      IOptionMarket.TradeParameters memory trade,
      IOptionGreekCache.TradePricing memory pricing,
      uint skew
    ) external view returns (VarianceFeeComponents memory varianceFeeComponents);

    function pricingParams() external view returns (PricingParameters memory);

    function ivImpactForTrade(
        IOptionMarket.TradeParameters memory trade,
        uint boardBaseIv,
        uint strikeSkew
    ) external view returns (uint newBaseIv, uint newSkew);
}