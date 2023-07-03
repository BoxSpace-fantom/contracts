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

//contracts deployed to: 0x089898e0b744aef9227BBb6dc7123843bFA8ccF1
