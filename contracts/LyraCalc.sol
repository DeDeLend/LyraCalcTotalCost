// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import {BlackScholes} from"./libraries/BlackScholes.sol";
import {DecimalMath} from "./synthetix/DecimalMath.sol";
import {SignedDecimalMath} from "./synthetix/SignedDecimalMath.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {IOptionMarket} from "./interfaces/IOptionMarket.sol";
import {IBaseExchangeAdapter} from "./interfaces/IBaseExchangeAdapter.sol";
import {IOptionGreekCache} from "./interfaces/IOptionGreekCache.sol";
import {IOptionMarketPricer} from "./interfaces/IOptionMarketPricer.sol";
import {ILiquidityPool} from "./interfaces/ILiquidityPool.sol";

/**
 * @title LyraCalc
 * @author 0nika0
 * @notice A smart contract for calculating the total cost of option trades and related fees.
 * This contract leverages the Black-Scholes model and various pricing parameters to estimate trade costs.
 */
contract LyraCalc {
    using DecimalMath for uint;
    using SignedDecimalMath for int;
    using BlackScholes for BlackScholes.BlackScholesInputs;
    
    // Contracts and libraries
    IOptionMarket public optionMarket;
    IOptionMarketPricer public optionMarketPricer;
    IBaseExchangeAdapter public baseExchangeAdapter;
    IOptionGreekCache public optionGreekCache;
    ILiquidityPool public liquidityPool;

    constructor(
        address _optionMarket,
        address _optionMarketPricer,
        address _baseExchangeAdapter,
        address _optionGreekCache,
        address _liquidityPool
    ) {
        optionMarket = IOptionMarket(_optionMarket);
        optionMarketPricer = IOptionMarketPricer(_optionMarketPricer);
        baseExchangeAdapter = IBaseExchangeAdapter(_baseExchangeAdapter);
        optionGreekCache = IOptionGreekCache(_optionGreekCache);
        liquidityPool = ILiquidityPool(_liquidityPool);
    }

    // VIEW FUNCTIONS //

    /**
     * @notice Calculates the total cost for a given trade.
     * @dev This function calculates the approximate value of an option trade based on various parameters.
     * @param strikeId The ID of the strike for the option trade.
     * @param tradeDirection The direction of the trade: OPEN, CLOSE, LIQUIDATE.
     * @param optionType The type of the option: LONG_CALL, LONG_PUT, SHORT_CALL_BASE, SHORT_CALL_QUOTE, SHORT_PUT_QUOTE.
     * @param amount The amount of options being traded.
     * @param isBuy True if it's a buy trade, false if it's a sell trade.
     * @param isForceClose True if the trade is a force close.
     * @return totalCost The total cost of the trade including fees.
     */
    function calculateTotalCost(
        uint256 strikeId,
        IOptionMarket.TradeDirection tradeDirection, 
        IOptionMarket.OptionType optionType, 
        uint256 amount,
        bool isBuy,
        bool isForceClose
    ) public view returns (uint256 totalCost) {
        // Prepare the trade parameters based on input values
        IOptionMarket.TradeParameters memory trade = preparetionTrade(
            amount,
            isBuy,
            tradeDirection,
            optionType,
            isForceClose
        );

        // Get strike and board information
        (IOptionMarket.Strike memory strike, IOptionMarket.OptionBoard memory board) = optionMarket.getStrikeAndBoard(strikeId);
        IOptionGreekCache.StrikeCache memory strikeCache = optionGreekCache.getStrikeCache(strikeId);
        IOptionGreekCache.OptionBoardCache memory boardCache = optionGreekCache.getOptionBoardCache(strikeCache.boardId);

        // Calculate prices, delta, and standard vega using Black-Scholes model
        BlackScholes.PricesDeltaStdVega memory pricesDeltaStdVega = calculatePricesDeltaStdVega(
            trade.spotPrice,
            strikeCache,
            boardCache
        );

        // Prepare trade pricing data
        IOptionGreekCache.TradePricing memory pricing = preparetionPricing(
            strike,
            strikeCache,
            boardCache,
            pricesDeltaStdVega.vega
        );

        // Calculate the impact of implied volatility on the trade's price
        (, uint256 newSkew) = optionMarketPricer.ivImpactForTrade(trade, boardCache.iv, strike.skew);

        // Calculate the premium for the option trade
        uint256 premium = calculatePremium(
            optionType,
            amount,
            pricesDeltaStdVega
        );

        // Calculate fees related to option price and spot price
        uint256 optionPriceFee = calculateOptionPriceFee(premium, board.expiry);
        uint256 spotPriceFee = calculateSpotPriceFee(trade.spotPrice, trade.amount, board.expiry);

        // Calculate vega utility and variance fees
        IOptionMarketPricer.VegaUtilFeeComponents memory vegaUtilFeeComponents = optionMarketPricer.getVegaUtilFee(
            trade,
            pricing
        );
        IOptionMarketPricer.VarianceFeeComponents memory varianceFeeComponents = optionMarketPricer.getVarianceFee(
            trade,
            pricing,
            newSkew
        );

        // Calculate the total fee for the trade
        uint totalFee = optionPriceFee +
            spotPriceFee +
            vegaUtilFeeComponents.vegaUtilFee +
            varianceFeeComponents.varianceFee;

        // Calculate the total cost based on trade direction and fees
        if (trade.isBuy) {
            totalCost = premium + totalFee;
        } else {
            if (totalFee > premium) {
                totalFee = premium;
                totalCost = 0;
            } else {
                totalCost = premium - totalFee;
            }
        }
        // Return the calculated total cost
    }

    /**
     * @notice Calculates option prices, delta, and standard vega using the Black-Scholes model.
     * @dev This function calculates various option-related values using the Black-Scholes formula.
     * @param spotPrice The current spot price of the underlying asset.
     * @param strikeCache The cached data for the strike associated with the option.
     * @param boardCache The cached data for the option board.
     * @return pricesDeltaStdVega A struct containing calculated prices, delta, and standard vega.
     */
    function calculatePricesDeltaStdVega(
        uint256 spotPrice,
        IOptionGreekCache.StrikeCache memory strikeCache,
        IOptionGreekCache.OptionBoardCache memory boardCache
    ) public view returns (BlackScholes.PricesDeltaStdVega memory pricesDeltaStdVega) {
        // Construct inputs for the Black-Scholes formula
        pricesDeltaStdVega = BlackScholes
            .BlackScholesInputs({
                timeToExpirySec: _timeToMaturitySeconds(boardCache.expiry), // Calculate time to maturity in seconds
                volatilityDecimal: boardCache.iv.multiplyDecimal(strikeCache.skew), // Adjusted volatility based on strike skew
                spotDecimal: spotPrice, // Current spot price
                strikePriceDecimal: strikeCache.strikePrice, // Strike price of the option
                rateDecimal: baseExchangeAdapter.rateAndCarry(address(optionMarket)) // Risk-free rate
            })
            .pricesDeltaStdVega();
    }

    /**
     * @notice Retrieves the appropriate spot price based on trade direction, option type, and force close status.
     * @param tradeDirection The direction of the trade: OPEN, CLOSE, LIQUIDATE.
     * @param optionType The type of the option: LONG_CALL, LONG_PUT, SHORT_CALL_BASE, SHORT_CALL_QUOTE, SHORT_PUT_QUOTE.
     * @param isForceClose True if the trade is a force close.
     * @return spotPrice The calculated spot price for the trade.
     */
    function getSpotPrice(
        IOptionMarket.TradeDirection tradeDirection,
        IOptionMarket.OptionType optionType,
        bool isForceClose
    ) public view returns (uint256 spotPrice) {
        IBaseExchangeAdapter.PriceType pricingType;

        // Determine the appropriate pricing type based on trade direction and option type
        if (tradeDirection == IOptionMarket.TradeDirection.LIQUIDATE) {
            pricingType = IBaseExchangeAdapter.PriceType.REFERENCE;
        } else if (optionType == IOptionMarket.OptionType.LONG_CALL || optionType == IOptionMarket.OptionType.SHORT_PUT_QUOTE) {
            pricingType = tradeDirection == IOptionMarket.TradeDirection.OPEN
                ? IBaseExchangeAdapter.PriceType.MAX_PRICE
                : (isForceClose ? IBaseExchangeAdapter.PriceType.FORCE_MIN : IBaseExchangeAdapter.PriceType.MIN_PRICE);
        } else {
            pricingType = tradeDirection == IOptionMarket.TradeDirection.OPEN
                ? IBaseExchangeAdapter.PriceType.MIN_PRICE
                : (isForceClose ? IBaseExchangeAdapter.PriceType.FORCE_MAX : IBaseExchangeAdapter.PriceType.MAX_PRICE);
        }

        // Retrieve the spot price based on the selected pricing type
        spotPrice = baseExchangeAdapter.getSpotPriceForMarket(address(optionMarket), pricingType);
    }

    /**
     * @notice Calculates the fee based on spot price and trade amount, taking into account time weighting.
     * @param spotPrice The current spot price of the underlying asset.
     * @param amount The amount of options being traded.
     * @param expiry The expiration time of the options.
     * @return fee The calculated fee based on the provided spot price and trade parameters.
     */
    function calculateSpotPriceFee(
        uint256 spotPrice,
        uint256 amount,
        uint256 expiry
    ) public view returns (uint256 fee) {
        // Get the pricing parameters from the option market pricer
        IOptionMarketPricer.PricingParameters memory pricingParams = optionMarketPricer.pricingParams();

        // Calculate the time-weighted spot price fee using the provided parameters
        uint timeWeightedSpotPriceFee = optionMarketPricer.getTimeWeightedFee(
            expiry,
            pricingParams.spotPriceFee1xPoint,
            pricingParams.spotPriceFee2xPoint,
            pricingParams.spotPriceFeeCoefficient
        );

        // Calculate the final fee by multiplying the time-weighted fee by the spot price and trade amount
        fee = timeWeightedSpotPriceFee.multiplyDecimal(spotPrice).multiplyDecimal(amount);
    }

    /**
     * @notice Calculates the fee based on the option premium and expiration time, considering time weighting.
     * @param premium The premium amount of the option.
     * @param expiry The expiration time of the option.
     * @return fee The calculated fee based on the provided premium and expiration time.
     */
    function calculateOptionPriceFee(
        uint256 premium,
        uint256 expiry
    ) public view returns (uint256 fee) {
        // Get the pricing parameters from the option market pricer
        IOptionMarketPricer.PricingParameters memory pricingParams = optionMarketPricer.pricingParams();

        // Calculate the time-weighted option price fee using the provided parameters
        uint timeWeightedOptionPriceFee = optionMarketPricer.getTimeWeightedFee(
            expiry,
            pricingParams.optionPriceFee1xPoint,
            pricingParams.optionPriceFee2xPoint,
            pricingParams.optionPriceFeeCoefficient
        );

        // Calculate the final fee by multiplying the time-weighted fee by the option premium
        fee = timeWeightedOptionPriceFee.multiplyDecimal(premium);
    } 

    /**
     * @notice Prepares deal parameters for totalCost calculation.
     * @param amount The amount of options being traded.
     * @param isBuy True if it's a buy trade, false if it's a sell trade.
     * @param tradeDirection The direction of the trade: OPEN, CLOSE, LIQUIDATE.
     * @param optionType The type of the option: LONG_CALL, LONG_PUT, SHORT_CALL_BASE, SHORT_CALL_QUOTE, SHORT_PUT_QUOTE.
     * @param isForceClose True if the trade is a force close.
     * @return trade The populated trade parameters.
    */
    function preparetionTrade(
        uint256 amount,
        bool isBuy,
        IOptionMarket.TradeDirection tradeDirection,
        IOptionMarket.OptionType optionType,
        bool isForceClose
    ) public view returns (IOptionMarket.TradeParameters memory trade) {
        // Get the current Net Asset Value (NAV) from the liquidity pool
        trade.liquidity.NAV = liquidityPool.getLiquidity().NAV;

        // Populate the trade parameters based on provided inputs
        trade.amount = amount;
        trade.isForceClose = isForceClose;
        trade.isBuy = isBuy;

        // Get the spot price for the trade based on trade direction, option type, and force close status
        trade.spotPrice = getSpotPrice(
            tradeDirection,
            optionType,
            isForceClose
        );

        // Set the option type and trade direction
        trade.optionType = optionType;
        trade.tradeDirection = tradeDirection;
    }

    /**
     * @notice Prepares trade pricing data based on strike and greek cache information.
     * @param strike The information about the strike.
     * @param strikeCache The cached data for the strike.
     * @param boardCache The cached data for the option board.
     * @param vega The calculated vega value.
     * @return pricing The populated trade pricing data.
     */
    function preparetionPricing(
        IOptionMarket.Strike memory strike,
        IOptionGreekCache.StrikeCache memory strikeCache,
        IOptionGreekCache.OptionBoardCache memory boardCache,
        uint256 vega
    ) public view returns (IOptionGreekCache.TradePricing memory pricing) {
        // Get the global cache from the option Greek cache
        IOptionGreekCache.GlobalCache memory globalCache = optionGreekCache.getGlobalCache();

        // Calculate new exposures and net standard vega difference
        int256 newCallExposure = SafeCast.toInt256(strike.longCall) - SafeCast.toInt256(strike.shortCallBase + strike.shortCallQuote);
        int256 newPutExposure = SafeCast.toInt256(strike.longPut) - SafeCast.toInt256(strike.shortPut);
        int256 netStdVegaDiff = (newCallExposure + newPutExposure - strikeCache.callExposure - strikeCache.putExposure)
            .multiplyDecimal(SafeCast.toInt256(strikeCache.greeks.stdVega));


        // Populate pricing data based on provided inputs
        pricing.preTradeAmmNetStdVega = -globalCache.netGreeks.netStdVega;
        pricing.postTradeAmmNetStdVega = -globalCache.netGreeks.netStdVega + netStdVegaDiff;
        pricing.volTraded = boardCache.iv.multiplyDecimal(strikeCache.skew);
        pricing.vega = vega;
        pricing.ivVariance = boardCache.ivVariance;
    }

    // INTERNAL FUNCTIONS //

    /**
     * @notice Calculates the time remaining to maturity in seconds for a given expiry timestamp.
     * @param expiry The expiration timestamp of the option.
     * @return timeToMaturitySeconds The remaining time to maturity in seconds.
     */
    function _timeToMaturitySeconds(uint256 expiry) internal view returns (uint256 timeToMaturitySeconds) {
        // Calculate the time remaining to maturity using the _getSecondsTo function
        timeToMaturitySeconds = _getSecondsTo(block.timestamp, expiry);
    }

    // PURE FUNCTIONS //

    /**
     * @notice Calculates the premium for the option trade based on the option type and other parameters.
     * @param optionType The type of the option: LONG_CALL, LONG_PUT, SHORT_CALL_BASE, SHORT_CALL_QUOTE, SHORT_PUT_QUOTE.
     * @param amount The amount of options being traded.
     * @param pricesDeltaStdVega The struct containing calculated prices, delta, and standard vega.
     * @return premium The calculated premium for the option trade.
     */
    function calculatePremium(
        IOptionMarket.OptionType optionType,
        uint256 amount,
        BlackScholes.PricesDeltaStdVega memory pricesDeltaStdVega
    ) public pure returns (uint256 premium) {
        // Determine the appropriate option price based on the option type
        uint256 optionPrice = (optionType != IOptionMarket.OptionType.LONG_PUT && optionType != IOptionMarket.OptionType.SHORT_PUT_QUOTE)
            ? pricesDeltaStdVega.callPrice
            : pricesDeltaStdVega.putPrice;
        // Calculate the premium by multiplying the option price by the trade amount
        premium = optionPrice.multiplyDecimal(amount);
    }

    /**
     * @notice Calculates the time difference in seconds between two timestamps.
     * @param fromTime The starting timestamp.
     * @param toTime The ending timestamp.
     * @return secondsTo The time difference in seconds between the two timestamps.
     */
    function _getSecondsTo(uint256 fromTime, uint256 toTime) internal pure returns (uint256) {
        // Calculate the time difference in seconds between the two timestamps
        if (toTime > fromTime) {
            return toTime - fromTime;
        }
            return 0;
    }

}
