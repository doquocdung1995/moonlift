const hre = require("hardhat")
const {
    masterChef_devAddress,
    masterChef_feeAddress,
    masterChef_eggPerBlock,
    masterChef_startBlock,
    timelock_admin,
    timelock_delay
} = require('./secrets.json')


async function main() {
    const chainId = (await hre.ethers.provider.getNetwork()).chainId
    let router = "0x0000000000000000000000000000000000000000";

    if (chainId === 97) { // testnet
        router = "0xD99D1c33F9fC3444f8101754aBC46c52416550D1"
    } else if (chainId === 56) {
        router = "0x05fF2B0DB69458A0750badebc4f9e13aDd608C7F"
    }

    const Moonlift = await hre.ethers.getContractFactory("Moonlift")
    const moonlift = await Moonlift.deploy(router, {gasLimit: 5e6})
    await moonlift.deployed();
    console.log("Moonlift deployed to:", moonlift.address);

    const MasterChef = await hre.ethers.getContractFactory("MasterChef")
    const masterChef = await MasterChef.deploy(
        moonlift.address,
        masterChef_devAddress,
        masterChef_feeAddress,
        masterChef_eggPerBlock,
        masterChef_startBlock,
        {gasLimit: 5e6})
    await masterChef.deployed()
    console.log("MasterChef deployed to:", masterChef.address);

    const Timelock = await hre.ethers.getContractFactory("Timelock")
    const timelock = await Timelock.deploy(
        timelock_admin,
        timelock_delay,
        {gasLimit: 5e6})
    await timelock.deployed()
    console.log("Timelock deployed to:", timelock.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });
