// scripts/deploy.js
// Deploy CmvngSignalVault to Arc Testnet
//
// Usage:
//   npx hardhat run scripts/deploy.js --network arcTestnet

const hre = require("hardhat");

async function main() {
  const [deployer] = await hre.ethers.getSigners();
  console.log("Deploying with account:", deployer.address);

  // ──────────────────────────────────────────────────────────
  // IMPORTANT: Replace this with the actual USDC ERC-20
  // contract address on Arc Testnet.
  //
  // Find it at:
  // https://docs.arc.network/arc/references/contract-addresses
  // ──────────────────────────────────────────────────────────
  const USDC_ADDRESS = "0x751174BF2269e13663C5a37fd9dD7714079ED0e3";

  console.log("USDC address:", USDC_ADDRESS);

  const CmvngSignalVault = await hre.ethers.getContractFactory("CmvngSignalVault");
  const contract = await CmvngSignalVault.deploy(USDC_ADDRESS);
  await contract.waitForDeployment();

  const address = await contract.getAddress();
  console.log("CmvngSignalVault deployed to:", address);
  console.log("");
  console.log("──────────────────────────────────────────────");
  console.log("SAVE THIS ADDRESS — you need it for:");
  console.log("  1. The checkout page (CONTRACT_ADDR)");
  console.log("  2. The payment listener (CONTRACT_ADDRESS)");
  console.log("  3. The Telegram bot config");
  console.log("──────────────────────────────────────────────");
  console.log("");
  console.log("Next steps:");
  console.log("  1. Verify on ArcScan: https://testnet.arcscan.app");
  console.log("  2. Fund your wallet with testnet USDC: https://faucet.circle.com");
  console.log("  3. Start the payment listener: node listener.js");
  console.log("  4. Start the Telegram bot: python bot.py");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
