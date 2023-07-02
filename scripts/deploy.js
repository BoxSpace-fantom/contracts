const hre = require("hardhat");

async function main() {

  // Deploy BoxSpace contract
  const BoxSpace = await hre.ethers.getContractFactory("BoxSpace");
  const boxSpace = await BoxSpace.deploy();
  await boxSpace.deployed();
  console.log("contracts deployed to:", boxSpace.address); 
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});

//contracts deployed to: 0x4e368562E3A07A08b7cA2f16c649702FbD485932
