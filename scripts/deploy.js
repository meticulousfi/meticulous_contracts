// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = require("hardhat");

let METAddress;
let METPlusAddress;

// npx hardhat verify --network sepolia 0x59002D42216814Df53C39D66fe830149D08f01D5
// npx hardhat verify --network sepolia 0x8bCF9280C08317Ed2Aacc4D6480C575693CD0a17 "0x98b941a891bdAcc51412114293A06FB8d80a08da" "0x59002D42216814Df53C39D66fe830149D08f01D5"

async function main() {

  const MET = await hre.ethers.getContractFactory("MetToken");
  let metToken;
  console.log("MetToken factory created.");
  try{
    metToken = await MET.deploy();
  }
  catch (error) {
    console.error("Error deploying MetToken:", error);
    process.exit(1);
  }
  console.log("MET Contract Address", metToken.target);
  METAddress = metToken.target;

  // await deployMetPlus();
}

// npx hardhat verify --network arbitrum 

async function deployMetPlus() {

  const METPlus = await hre.ethers.getContractFactory("METPlus");
  let metPlusToken;
  console.log("METPlus factory created.");
  try{
    metPlusToken = await METPlus.deploy();
  }
  catch (error) {
    console.error("Error deploying METPlus:", error);
    process.exit(1);
  }
  console.log("METPlus Contract Address", metPlusToken.target);
  METPlusAddress = metPlusToken.target;

  // await deployStakeMet();
}

// npx hardhat verify --network arbitrum 

async function deployStakeMet() {

  const METStake = await hre.ethers.getContractFactory("StakeMET");
  let metStake;
  console.log("METPlus factory created.");
  try{
    metStake = await METStake.deploy("0x98b941a891bdAcc51412114293A06FB8d80a08da", "0x59002D42216814Df53C39D66fe830149D08f01D5");
  }
  catch (error) {
    console.error("Error deploying METStake:", error);
    process.exit(1);
  }
  console.log("METStake Contract Address", metStake.target);
}

deployStakeMet().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
