import { LyraCalc } from "../typechain-types";
import { IOptionMarket } from "../typechain-types";
import { IOptionMarketPricer } from "../typechain-types";
import { IOptionGreekCache } from "../typechain-types";
import { IOptionBuilder } from "../typechain-types";
import { IERC20 } from "../typechain-types"; 
import {BigNumber as BN, Signer} from "ethers"
import { parseUnits, formatUnits } from "ethers/lib/utils";
import {ethers, deployments} from "hardhat"

const hre = require("hardhat");

async function main() {
  const [ deployer ] = await hre.ethers.getSigners()

  let lyraCalc = (await hre.ethers.getContract("lyraCalc")) as LyraCalc
  let USDC = (await hre.ethers.getContract("USDC")) as IERC20
  let optionMarket = (await hre.ethers.getContract("IOptionMarket")) as IOptionMarket
  let optionGreekCache = (await hre.ethers.getContract("IOptionGreekCache")) as IOptionGreekCache
  let optionMarketPricer = (await hre.ethers.getContract("IOptionMarketPricer")) as IOptionMarketPricer

  console.log("lyraCalc address: ", lyraCalc.address)

  const strikeId = 448
  const optionType = 0
  const tradeDirection = 0
  const amount = BN.from("100000000000000000")
  const isBuy = true
  const isForceClose = false

  const params = {    
        strikeId: strikeId,
        positionId: 0,
        iterations: 1,
        optionType: optionType,
        amount: amount,
        setCollateralTo: 0,
        minTotalCost: 0,
        maxTotalCost: BN.from("1829051399472336769"),
        referrer: ethers.constants.AddressZero
    }

  let totalCost = await lyraCalc.calculateTotalCost(strikeId, tradeDirection, optionType, amount, isBuy, isForceClose)
  console.log("\ntotalCost: ", formatUnits(totalCost, 18), "\n")

  let trade = await lyraCalc.preparetionTrade(amount, isBuy, tradeDirection, optionType, isForceClose)

  let strikeAndBoard = await optionMarket.getStrikeAndBoard(strikeId);
  const strike = strikeAndBoard[0]
  const board = strikeAndBoard[1]

  let strikeCache = await optionGreekCache.getStrikeCache(strikeId)
  let boardCache = await optionGreekCache.getOptionBoardCache(strikeCache.boardId)

  let pricesDeltaStdVega = await lyraCalc.calculatePricesDeltaStdVega(trade.spotPrice, strikeCache, boardCache)
  let premium = await lyraCalc.calculatePremium(optionType, amount, pricesDeltaStdVega)

  const pricing = await lyraCalc.preparetionPricing(strike, strikeCache, boardCache, pricesDeltaStdVega.vega)
  const newSkew = (await optionMarketPricer.ivImpactForTrade(trade, boardCache.iv, strike.skew))[1];

  const optionPriceFee = await lyraCalc.calculateOptionPriceFee(premium, board.expiry)
  const spotPriceFee = await lyraCalc.calculateSpotPriceFee(trade.spotPrice, trade.amount, board.expiry)
  const vegaUtilFeeComponents = await optionMarketPricer.getVegaUtilFee(trade, pricing)
  const varianceFeeComponents = await optionMarketPricer.getVarianceFee(trade, pricing, strike.skew)

  console.log("premium: ", formatUnits(premium, 18))
  console.log("optionPriceFee: ", formatUnits(optionPriceFee, 18))
  console.log("spotPriceFee: ", formatUnits(spotPriceFee, 18))
  console.log("vegaUtilFeeComponents.vegaUtilFee: ", formatUnits(vegaUtilFeeComponents.vegaUtilFee, 18))
  console.log("varianceFeeComponents.varianceFee: ", formatUnits(varianceFeeComponents.varianceFee, 18))

  const balance_before = await USDC.balanceOf(deployer.address)
  await optionMarket.openPosition(params)
  const balance_after = await USDC.balanceOf(deployer.address)
  console.log("the total cost: ",formatUnits(balance_before.sub(balance_after), 6))

}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
