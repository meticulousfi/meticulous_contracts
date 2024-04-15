require("@nomicfoundation/hardhat-toolbox");
const CONFIG = require("./credentials.json");

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.8.20",
  networks: {
    arbitrum: {
			url: CONFIG["Mainnet_ARB"],
			accounts: [CONFIG["PKEY2"]],
		},
    goerli: {
			url: CONFIG["GOERLI"]["URL"],
			accounts: [CONFIG["GOERLI"]["PKEY"]],
		},
    sepolia: {
      url: CONFIG["SEPOLIA"]["URL"],
      accounts: [CONFIG["SEPOLIA"]["PKEY"]]
    },
    hardhat: {
      forking: {
        url: CONFIG["API_KEY"], // Replace with your Alchemy API key
      },
    },
  },
  etherscan: {
    apiKey: CONFIG["ARB_KEY"],
  },
  sourcify: {
    enabled: true
  },
};
