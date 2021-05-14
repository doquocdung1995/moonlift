require("@nomiclabs/hardhat-waffle")
require('@nomiclabs/hardhat-ethers')
require("@nomiclabs/hardhat-etherscan");

const { mnemonic, bscScanApiKey } = require('./secrets.json')

task("account", "Prints account address", async () => {
  const wallet = await ethers.Wallet.fromMnemonic(mnemonic)
  console.log(`Account address: ${wallet.address}`)
})
task("new_wallet", "Generates account address", async () => {
  const wallet = await ethers.Wallet.createRandom()
  console.log("New wallet:\n")
  console.log(`\tAddress: ${wallet.address}`)
  console.log(`\tMnemonic: ${wallet._mnemonic().phrase}`)
})

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  defaultNetwork: "mainnet",
  networks: {
    localhost: {
      url: "http://127.0.0.1:8545"
    },
    hardhat: {
    },
    testnet: {
      url: "https://data-seed-prebsc-1-s1.binance.org:8545",
      chainId: 97,
      gasPrice: 20000000000,
      accounts: {mnemonic: mnemonic}
    },
    mainnet: {
      url: "https://bsc-dataseed.binance.org/",
      chainId: 56,
      gasPrice: 20000000000,
      accounts: {mnemonic: mnemonic}
    }
  },
  solidity: {
    version: "0.6.12",
    settings: {
      optimizer: {
        enabled: true
      }
    }
  },
  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts"
  },
  mocha: {
    timeout: 20000
  },
  etherscan: {
    // Your API key for Etherscan
    // Obtain one at https://etherscan.io/
    apiKey: bscScanApiKey
  }
}
