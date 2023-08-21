import hre from "hardhat"
import "dotenv/config"

async function main() {
    const VNST = await hre.ethers.getContractFactory("VNSTProtocol")
    console.log("Upgrading VNST ...")
    const vnst = await hre.upgrades.upgradeProxy(process.env.PROXYTESTNETADDRESS as string, VNST)
    console.log("VNST deployed to:", vnst.target)
}

main().catch((error) => {
    console.error(error)
    process.exitCode = 1
})
