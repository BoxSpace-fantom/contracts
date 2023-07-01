
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

  networks: {
    moonbase: {
      url: 'https://moonbase-alpha.public.blastapi.io',
      chainId: 1287, 
      accounts: [privateKey],
      gas: 12000000,
      timeout: 1800000
    }
  }
};

//contracts deployed to: 0x4e368562E3A07A08b7cA2f16c649702FbD485932