import { ethers, upgrades } from "hardhat";

async function main() {
  const ERC20_TOKEN = "";

  const TokenTimelockVaultFactory = await ethers.getContractFactory("TokenTimelockVault");
  const TokenTimelockVault = await upgrades.deployProxy(TokenTimelockVaultFactory, [ERC20_TOKEN], { kind: "uups" });
  await TokenTimelockVault.deployed();

  console.log(`Hash: ${TokenTimelockVault.deployTransaction.hash}`);
  console.log(`Address: ${TokenTimelockVault.address}`);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
