require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-etherscan");

task("accounts", "Prints the list of accounts", async (taskArgs, hre) => {
  const accounts = await hre.ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

module.exports = {
  solidity: "0.8.4",
  etherscan: {
    apiKey: "ATJAMMWMGWG9CM3JHCQDCRCXSR4UZQ5618",
  },
  networks: {
    kovan: {
      url: "https://kovan.infura.io/v3/f87b967bc65a41c0a1a25635493fa482",
      accounts: [``],
    },
    ropsten: {
      url: "https://ropsten.infura.io/v3/f87b967bc65a41c0a1a25635493fa482",
      accounts: [""],
    },
    goerli: {
      url: "https://goerli.infura.io/v3/f87b967bc65a41c0a1a25635493fa482",
      accounts: [``],
    },
    bscTestnet: {
      url: `https://data-seed-prebsc-1-s1.binance.org:8545`,
      accounts: [``],
    },
    mainnet: {
      url: `https://bsc-dataseed.binance.org/`,
      accounts: [``],
    },
  },
};
