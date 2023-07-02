
require('@nomiclabs/hardhat-ethers');

const { privateKey } = require('./secrets.json');

module.exports = {
  solidity: "0.8.18",
  
  settings: {
    optimizer: {
      enabled: true,
      runs: 10,
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

//moonbase - contracts deployed to: 0x4e368562E3A07A08b7cA2f16c649702FbD485932

//Fantom testnet - contracts deployed to: 0x1e3a926639CB2d60219E15976c24493b9e635169