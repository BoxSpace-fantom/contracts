
require('@nomiclabs/hardhat-ethers');

const { privateKey } = require('./secrets.json');

module.exports = {
  solidity: "0.8.18",
  
  settings: {
    optimizer: {
      enabled: true,
      runs: 200,
    },
    viaIR: true,
    
  },

  defaultNetwork: "testnet",
  networks: {
    moonbase: {
      url: 'https://moonbase-alpha.public.blastapi.io',
      chainId: 1287, 
      accounts: [privateKey],
      gas: 12000000,
      timeout: 1800000
    },
    mainnet: {
      url: `https://rpcapi.fantom.network`,
      chainId: 250,
      accounts: [privateKey]
    },
    testnet: {
      url: `https://rpc.testnet.fantom.network`,
      chainId: 4002,
      accounts: [privateKey]
    },
  }
};


//Fantom mainnet - contracts deployed to: 0x089898e0b744aef9227BBb6dc7123843bFA8ccF1