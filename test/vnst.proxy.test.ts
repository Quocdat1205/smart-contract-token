import { expect } from "chai"
import hre from "hardhat"

import { sqrt } from "./helpers"

let usdt: any
let vnstProxy: any
let vnst: any
let mock: any
let owner: any
let mod: any
const _rate_decimal: bigint = hre.ethers.toBigInt(1000000)

describe("VNST", function () {
    this.beforeAll(async function () {
        ;[owner, mod] = await hre.ethers.getSigners()
        const USDT = await hre.ethers.getContractFactory("USDT")
        console.log("Deploying USDT ...")
        usdt = await USDT.deploy()
        console.log("USDT deployed to:", usdt.target)

        const VNSTProxy = await hre.ethers.getContractFactory("VNSTProxy")
        console.log("Deploying VNST Proxy ...")

        vnstProxy = await hre.upgrades.deployProxy(VNSTProxy, [usdt.target], {
            kind: "uups",
        })

        const VNST_PROXY_ADDRESS = await vnstProxy.getAddress()
        console.log("VNST Proxy deployed to:", VNST_PROXY_ADDRESS)

        await usdt.approve(VNST_PROXY_ADDRESS, hre.ethers.parseEther("10000000"))

        const VNST = await hre.ethers.getContractFactory("VNSTProtocol")

        console.log("Deploying VNST ...")
        vnst = await hre.upgrades.upgradeProxy(vnstProxy, VNST)
        console.log("VNST deployed to:", vnst.target)

        const MockVNST = await hre.ethers.getContractFactory("MockVNST")

        console.log("Deploying mock contract ...")
        mock = await hre.upgrades.upgradeProxy(vnstProxy, MockVNST)
        console.log("Mock deployed to: ", mock.target)
    })

    it("Proxy work correctly", async () => {
        expect(await vnstProxy.getAddress()).to.equal(await vnst.getAddress())
        expect(await vnst.version()).to.equal("v1!")
    })

    it("Pauseable work correctly", async () => {
        await vnst.pause()

        await expect(vnst.mint(BigInt(1000 * 10 ** 18))).to.be.revertedWith("Pausable: paused")
        await vnst.unpause()

        await expect(vnst.connect(mod).pause()).to.be.revertedWith(
            "Ownable: caller is not the owner",
        )
    })

    async function reBootPool() {
        await vnst.reBootPool(
            hre.ethers.toBigInt(25000000000),
            hre.ethers.parseEther("30000000"),
            hre.ethers.parseEther("100000"),
            hre.ethers.parseEther("2500000000"),
        )
    }

    it("Reboot Pool work correctly", async () => {
        await reBootPool()
        expect(await vnst.market_price()).to.equal(hre.ethers.toBigInt(25000000000))
        expect(await vnst.usdt_pool()).to.equal(hre.ethers.parseEther("30000000"))
        expect(await vnst.vnst_pool()).to.equal(hre.ethers.parseEther("750000000000"))
        expect(await vnst.redeem_covered_amount()).to.equal(hre.ethers.parseEther("100000"))
        expect(await vnst.mint_covered_amount()).to.equal(hre.ethers.parseEther("2500000000"))
        expect(await vnst.redeem_covered_price()).to.equal(hre.ethers.toBigInt(25200000000))
        expect(await vnst.mint_covered_price()).to.equal(hre.ethers.toBigInt(24900000000))
        expect(await vnst.k()).to.equal(
            hre.ethers.parseEther("22500000000000000000000000000000000000"),
        )
    })

    it("Set moderator role function work correctly", async () => {
        await expect(
            vnst
                .connect(mod)
                .reBootPool(
                    hre.ethers.toBigInt(25000000000),
                    hre.ethers.parseEther("30000000"),
                    hre.ethers.parseEther("100000"),
                    hre.ethers.parseEther("2500000000"),
                ),
        ).to.be.revertedWith("Caller doesn't have permission")

        await vnst.addMod(mod.address)

        await vnst
            .connect(mod)
            .reBootPool(
                hre.ethers.toBigInt(25000000000),
                hre.ethers.parseEther("30000000"),
                hre.ethers.parseEther("100000"),
                hre.ethers.parseEther("2500000000"),
            )

        expect(await vnst.market_price()).to.equal(hre.ethers.toBigInt(25000000000))

        await vnst.removeMod(mod.address)

        await expect(
            vnst
                .connect(mod)
                .reBootPool(
                    hre.ethers.toBigInt(25000000000),
                    hre.ethers.parseEther("30000000"),
                    hre.ethers.parseEther("100000"),
                    hre.ethers.parseEther("2500000000"),
                ),
        ).to.be.revertedWith("Caller doesn't have permission")
    })

    it("Mint require work correctly", async () => {
        await expect(vnst.mint(hre.ethers.parseEther("10000000000"))).to.be.revertedWith(
            "USDT doesn't enough",
        )
        await expect(vnst.mint(hre.ethers.parseEther("1"))).to.be.revertedWith(
            "Min amount usdt is 5",
        )
        // Something wrong case
    })

    it("Mint function case VMM not available work correctly", async () => {
        const u = await vnst.usdt_pool()
        const v = await vnst.vnst_pool()
        const r = await vnst.mint_covered_price()

        const amount_usdt_in_before_support = getUSDTInBeforeCovered(u, v, r)

        // VMM not available after this mint
        await vnst.mint(amount_usdt_in_before_support)

        expect(await vnst.market_price()).to.equal(await vnst.mint_covered_price())
        expect(await vnst.mint_covered_amount()).to.equal(hre.ethers.parseEther("2500000000"))

        await vnst.mint(hre.ethers.parseEther("100"))

        const amount_vnst_support_out = (hre.ethers.parseEther("100") * r) / _rate_decimal

        expect(await vnst.mint_covered_amount()).to.equal(
            hre.ethers.parseEther("2500000000") - amount_vnst_support_out,
        )
    })

    it("Mint function case VMM available and mint don't hit cover price work correctly", async () => {
        await reBootPool()

        expect(await vnst.market_price()).to.equal(hre.ethers.toBigInt(25000000000))
        const x = await vnst.usdt_pool()

        const y = await vnst.vnst_pool()

        const Dx = hre.ethers.parseEther("1000")

        const Dy = calculateVMM(x, y, Dx)

        await vnst.mint(hre.ethers.parseEther("1000"))

        const market_price_after_mint = await vnst.market_price()

        expect(market_price_after_mint).to.equal(((y - Dy) * _rate_decimal) / (x + Dx))
    })

    // @todo Give this test more detail
    it("Mint function case VMM available and mint hit cover price work correctly", async () => {
        await reBootPool()
        expect(await vnst.market_price()).to.equal(hre.ethers.toBigInt(25000000000))

        await vnst.mint(hre.ethers.parseEther("60200"))

        expect(await vnst.market_price()).to.equal(await vnst.mint_covered_price())

        expect(await vnst.mint_covered_amount()).to.equal(
            hre.ethers.toBigInt(2499516992478936801354343600n),
        )
    })

    it("Redeem require work correctly", async () => {
        await expect(vnst.redeem(hre.ethers.parseEther("1000000000000"))).to.be.revertedWith(
            "VNST doesn't enough",
        )
        await expect(vnst.redeem(hre.ethers.parseEther("1"))).to.be.revertedWith(
            "Min amount vnst is 100000",
        )
        // Something wrong case
    })

    // @note This test is best practice but doesn't work yet
    // it("Redeem function case VMM not available work correctly", async () => {
    //     await vnst.mint(hre.ethers.parseEther("10000"))
    //     await reBootPool()
    //     expect(await vnst.market_price()).to.equal(hre.ethers.toBigInt(25000000000))

    //     const u = await vnst.usdt_pool()
    //     const v = await vnst.vnst_pool()
    //     const r = await vnst.redeem_covered_price()

    //     const amount_vnst_in_before_support = getVNSTInBeforeCovered(u, v, r)
    //     console.log(amount_vnst_in_before_support)
    //     // VMM not available after this redeem
    //     await vnst.redeem(amount_vnst_in_before_support)

    //     expect(await vnst.market_price()).to.equal(await vnst.redeem_covered_price())
    //     expect(await vnst.redeem_covered_amount()).to.equal(hre.ethers.parseEther("100000"))
    // })

    // @note This test is not so good practice but it's good enough and it's work
    it("Redeem function case VMM not available work correctly", async () => {
        await reBootPool()

        await mock.setMarketPrice(hre.ethers.toBigInt(25200000000))

        expect(await vnst.market_price()).to.equal(await vnst.redeem_covered_price())
        expect(await vnst.redeem_covered_amount()).to.equal(hre.ethers.parseEther("100000"))

        await vnst.redeem(hre.ethers.parseEther("100000"))

        const expected_redeem_covered_amount =
            hre.ethers.parseEther("100000") -
            (hre.ethers.parseEther("100000") * _rate_decimal) / hre.ethers.toBigInt(25200000000)

        expect(await vnst.redeem_covered_amount()).to.equal(expected_redeem_covered_amount)

        await reBootPool()

        // @todo test operation pool
    })

    it("Redeem function case VMM available and redeem don't hit r support work correctly", async () => {
        await vnst.mint(hre.ethers.parseEther("10000"))
        await reBootPool()

        expect(await vnst.market_price()).to.equal(hre.ethers.toBigInt(25000000000))
        const x = await vnst.vnst_pool()

        const y = await vnst.usdt_pool()

        const Dx = hre.ethers.parseEther("10000000")

        const Dy = calculateVMM(x, y, Dx)

        await vnst.redeem(hre.ethers.parseEther("10000000"))

        const market_price_after_redeem = await vnst.market_price()

        expect(market_price_after_redeem).to.equal(((x + Dx) * _rate_decimal) / (y - Dy))

        // @note correct test
        // expect(await vnst.operation_pool()).to.equal(Dy / BigInt(1000))
    })

    it("Redeem function case VMM available and redeem hit cover price work correctly", async () => {
        await vnst.mint(hre.ethers.parseEther("50000"))
        await reBootPool()

        expect(await vnst.market_price()).to.equal(hre.ethers.toBigInt(25000000000))

        const u = await vnst.usdt_pool()
        const v = await vnst.vnst_pool()
        const r = await vnst.redeem_covered_price()

        const amount_vnst_in_before_support = getVNSTInBeforeCovered(u, v, r)

        await vnst.redeem(hre.ethers.parseEther("3000000000"))

        const expected_redeem_covered_amount =
            hre.ethers.parseEther("100000") -
            ((hre.ethers.parseEther("3000000000") - amount_vnst_in_before_support) *
                _rate_decimal) /
                hre.ethers.toBigInt(25200000000)

        // expect(await vnst.market_price()).to.equal(await vnst.redeem_covered_price())

        expect(await vnst.redeem_covered_amount()).to.equal(
            hre.ethers.toBigInt(expected_redeem_covered_amount),
        )

        // @todo check operation pool
    })

    it("Withdraw to owner wallet in case of emergency work correctly", async () => {
        let usdtInVNST = await usdt.balanceOf(vnst.getAddress())

        await vnst.emergencyWithdraw()

        usdtInVNST = await usdt.balanceOf(vnst.getAddress())

        expect(usdtInVNST).to.equal(0)
        expect(await vnst.operation_pool()).to.equal(0)
    })

    it("Withdraw usdt and revenue functions work correctly", async () => {
        await vnst.mint(hre.ethers.parseEther("10000"))
        await vnst.redeem(hre.ethers.parseEther("10000000"))
        await reBootPool()

        let usdtInVNST = await usdt.balanceOf(vnst.getAddress())
        const operation_pool = await vnst.operation_pool()
        await vnst.withdrawUSDT(usdtInVNST - operation_pool)

        usdtInVNST = await usdt.balanceOf(vnst.getAddress())

        expect(usdtInVNST).to.equal(await vnst.operation_pool())

        expect(await vnst.operation_pool()).to.not.equal(0)

        await vnst.withdrawOperationPool()

        expect(await vnst.operation_pool()).to.equal(0)
    })
})

function calculateVMM(x: bigint, y: bigint, Dx: bigint) {
    const Dy = (y * Dx) / (x + Dx)
    return Dy
}

function getUSDTInBeforeCovered(u: bigint, v: bigint, r: bigint) {
    const k = v * u
    const Du = sqrt((k * _rate_decimal) / r) - u
    return Du
}

function getVNSTInBeforeCovered(u: bigint, v: bigint, r: bigint) {
    const k: bigint = v * u
    const Dy = sqrt((k * r) / _rate_decimal) - v
    return Dy
}
