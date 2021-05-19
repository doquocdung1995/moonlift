const hre = require("hardhat")


async function main() {
    const chainId = (await hre.ethers.provider.getNetwork()).chainId
    let router = "0x0000000000000000000000000000000000000000"
    let busd = "0x0000000000000000000000000000000000000000"

    if (chainId === 97) { // testnet
        router = "0xD99D1c33F9fC3444f8101754aBC46c52416550D1"
        busd = "0x8301f2213c0eed49a7e28ae4c3e91722919b8b47"
    } else if (chainId === 56) { // mainnet
        router = "0x05fF2B0DB69458A0750badebc4f9e13aDd608C7F"
        busd = "0xe9e7cea3dedca5984780bafc599bd69add087d56"
    }

    const Moonlift = await hre.ethers.getContractFactory("Moonlift")
    const moonlift = await Moonlift.deploy(router, busd)
    await moonlift.deployed();
    console.log("Moonlift deployed to:", moonlift.address)
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });
