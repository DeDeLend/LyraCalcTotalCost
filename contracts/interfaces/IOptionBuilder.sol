// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import "./IOptionMarket.sol";

interface IOptionBuilder {
    enum ProtocolType {
        lyra_eth,
        lyra_btc,
        hegic
    }

    struct TradeInputParameters {
        uint strikeId;
        uint positionId;
        uint iterations;
        IOptionMarket.OptionType optionType;
        uint amount;
        uint setCollateralTo;
        uint minTotalCost;
        uint maxTotalCost;
        address referrer;
    }

    function consolidationOfTransactions(ProtocolType[] memory protocolsArrays, bytes[] memory parametersArray, uint256 productType) external;
    function encodeFromLyra(TradeInputParameters memory params) external pure returns (bytes memory paramData);
}