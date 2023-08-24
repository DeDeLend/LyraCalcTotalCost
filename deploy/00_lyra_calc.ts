import {HardhatRuntimeEnvironment} from "hardhat/types"

async function deployment(hre: HardhatRuntimeEnvironment): Promise<void> {
  const {deployments, getNamedAccounts, network} = hre
  const {deploy, save, getArtifact} = deployments
  const {deployer} = await getNamedAccounts()

  await deploy("lyraCalc", {
    contract: "LyraCalc",
    from: deployer,
    log: true,
    libraries: {
      BlackScholes: "0xEAC659b8e6458568D84A278d1a1b286DD1e9511B",
    },
    args: [
      "0x919E5e0C096002cb8a21397D724C4e3EbE77bC15", // _optionMarket
      "0xdacEE745b517C9cDfd7F749dFF9eB03f51a27A13", // _optionMarketPricer
      "0x7D135662818d3540bd6f23294bFDB6946c52C9AB", // _baseExchangeAdapter
      "0x4b236Ac3B8d4666CbdC4E725C4366382AA30d86b", // _optionGreekCache
      "0xB619913921356904Bf62abA7271E694FD95AA10D" // _liquidityPool
    ],
  })

  save("IOptionMarket", {
    address: "0x919E5e0C096002cb8a21397D724C4e3EbE77bC15",
    abi: await getArtifact("contracts/interfaces/IOptionMarket.sol:IOptionMarket").then((x) => x.abi),
  })

  save("IOptionMarketPricer", {
    address: "0xdacEE745b517C9cDfd7F749dFF9eB03f51a27A13",
    abi: await getArtifact("contracts/interfaces/IOptionMarketPricer.sol:IOptionMarketPricer").then((x) => x.abi),
  })

  save("IBaseExchangeAdapter", {
    address: "0x7D135662818d3540bd6f23294bFDB6946c52C9AB",
    abi: await getArtifact("contracts/interfaces/IBaseExchangeAdapter.sol:IBaseExchangeAdapter").then((x) => x.abi),
  })

  save("IOptionGreekCache", {
    address: "0x4b236Ac3B8d4666CbdC4E725C4366382AA30d86b",
    abi: await getArtifact("contracts/interfaces/IOptionGreekCache.sol:IOptionGreekCache").then((x) => x.abi),
  })

  save("ILiquidityPool", {
    address: "0xB619913921356904Bf62abA7271E694FD95AA10D",
    abi: await getArtifact("contracts/interfaces/ILiquidityPool.sol:ILiquidityPool").then((x) => x.abi),
  })

  save("IOptionBuilder", {
    address: "0x18C9D966Fc60966c4bb0F5d098A005Ba8093380d",
    abi: await getArtifact("contracts/interfaces/IOptionBuilder.sol:IOptionBuilder").then((x) => x.abi),
  })

  save("USDC", {
    address: "0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8",
    abi: await getArtifact("contracts/interfaces/IERC20.sol:IERC20").then((x) => x.abi),
  })
}

deployment.tags = ["test", "arbitrum"]
export default deployment
