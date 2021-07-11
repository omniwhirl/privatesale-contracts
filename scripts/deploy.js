const hre = require("hardhat");
require("@nomiclabs/hardhat-etherscan");


const verify = async (_contractName, _contractAddress, _network, ...contract_args) => {
  let exec_command = `npx hardhat verify --network ${_network} ${_contractAddress} `;
  for (contract_arg of contract_args) {
    exec_command += contract_arg + " ";
  }
  console.log(`Verifying ${_contractName} Contract\n`);
  const { stdout, stderr } = await exec(exec_command.trim());
  if (stderr != null) {
    console.log('success:', stdout)
  } else {
    console.log('stderr:', stderr)
  }
}

async function main() {

  const WHIRL = await hre.ethers.getContractFactory("WHIRL");
  const PrivateSale = await hre.ethers.getContractFactory("PrivateSale");

  // Deploy $WHIRL
  let totalSupply = hre.ethers.BigNumber.from(10000000);  // 10 Million
  let initialSupply = hre.ethers.BigNumber.from(1000000);  // 1 Million
  const _WHIRL = await WHIRL.deploy(totalSupply, initialSupply);
  await _WHIRL.deployed();
  var token_address = _WHIRL.address;
  console.log('$WHIRL deployed to:', token_address, '\n');

  // Deploy Private Sale contract
  let stableCoinAddress = "0xc2132d05d31c914a87c6611c10748aeb04b58e8f" // USDT on mainnet
  const _PrivateSale = await PrivateSale.deploy(token_address, stableCoinAddress);
  await _PrivateSale.deployed();
  var sale_address = _PrivateSale.address;
  console.log('Private Sale contract deployed to:', sale_address, '\n');

  // Verify the contracts
  verify('$WHIRL Token', token_address, "matic", totalSupply, initialSupply);
  verify('Private Sale', sale_address, "matic", token_address, stableCoinAddress);
}


main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
