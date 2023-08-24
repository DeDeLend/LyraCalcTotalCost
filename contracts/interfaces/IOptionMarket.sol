pragma solidity 0.8.16;

import "./ILiquidityPool.sol";

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

interface IOptionMarket {
    enum TradeDirection {
        OPEN,
        CLOSE,
        LIQUIDATE
    }

    enum OptionType {
        LONG_CALL,
        LONG_PUT,
        SHORT_CALL_BASE,
        SHORT_CALL_QUOTE,
        SHORT_PUT_QUOTE
    }

    struct TradeInputParameters {
        // id of strike
        uint strikeId;
        // OptionToken ERC721 id for position (set to 0 for new positions)
        uint positionId;
        // number of sub-orders to break order into (reduces slippage)
        uint iterations;
        // type of option to trade
        OptionType optionType;
        // number of contracts to trade
        uint amount;
        // final amount of collateral to leave in OptionToken position
        uint setCollateralTo;
        // revert trade if totalCost is below this value
        uint minTotalCost;
        // revert trade if totalCost is above this value
        uint maxTotalCost;
        // referrer emitted in Trade event, no on-chain interaction
        address referrer;
    }

    struct Strike {
        // strike listing identifier
        uint256 id;
        // strike price
        uint256 strikePrice;
        // volatility component specific to the strike listing (boardIv * skew = vol of strike)
        uint256 skew;
        // total user long call exposure
        uint256 longCall;
        // total user short call (base collateral) exposure
        uint256 shortCallBase;
        // total user short call (quote collateral) exposure
        uint256 shortCallQuote;
        // total user long put exposure
        uint256 longPut;
        // total user short put (quote collateral) exposure
        uint256 shortPut;
        // id of board to which strike belongs
        uint256 boardId;
    }

    struct OptionBoard {
        // board identifier
        uint256 id;
        // expiry of all strikes belonging to board
        uint256 expiry;
        // volatility component specific to board (boardIv * skew = vol of strike)
        uint256 iv;
        // admin settable flag blocking all trading on this board
        bool frozen;
        // list of all strikes belonging to this board
        uint256[] strikeIds;
    }

    struct TradeParameters {
        bool isBuy;
        bool isForceClose;
        TradeDirection tradeDirection;
        OptionType optionType;
        uint amount;
        uint expiry;
        uint strikePrice;
        uint spotPrice;
        ILiquidityPool.Liquidity liquidity;
    }

    struct Result {
        uint positionId;
        uint totalCost;
        uint totalFee;
    }

    function getStrike(uint strikeId) external view returns (Strike memory);
    function getStrikeAndBoard(uint strikeId) external view returns (Strike memory, OptionBoard memory);
    function openPosition(TradeInputParameters memory params) external returns (Result memory result);
    function closePosition(TradeInputParameters memory params) external returns (Result memory result);
    function quoteAsset() external view returns(ERC20);
    function baseAsset() external view returns(ERC20);
}