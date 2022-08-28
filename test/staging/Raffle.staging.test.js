const { assert, expect } = require("chai")
const { network, getNamedAccounts, deployments, ethers } = require("hardhat")
const {
  developmentChains,
  networkConfig,
} = require("../../helper-hardhat-config")

developmentChains.includes(network.name)
  ? describe.skip
  : describe("Raffle", () => {
      let raffle, raffleEntranceFee, deployer

      beforeEach(async () => {
        deployer = (await getNamedAccounts()).deployer
        // await deployments.fixture(["all"]) // run deployments tagged 'all'
        raffle = await ethers.getContract("Raffle", deployer)
        raffleEntranceFee = await raffle.getEntranceFee()
      })

      describe("fulfillRandomWords", () => {
        it("works with live chainlink keepers and chainlink vrf. We get a random winner", async () => {
          const startingTimestamp = raffle.getLastTimeStamp()
          const accounts = await ethers.getSigners()

          await new Promise(async (resolve, reject) => {
            raffle.once("WinnerPicked", async () => {
              console.log("WinnerPicked event fired!")
              try {
                const recentWinner = await raffle.getRecentWinner()
                const raffleState = await raffle.getRaffleState()
                const winnerEndingBalance = await accounts[0].getBalance()
                const endingTimeStamp = await raffle.getLastTimeStamp()

                await expect(raffle.getPlayer(0)).to.be.reverted
                assert.equal(recentWinner.toString(), accounts[0].address)
                assert.equal(raffleState, 0)
                assert.equal(
                  winnerEndingBalance.toString(),
                  winnerStartingBalance.add(raffleEntranceFee).toString()
                )
                assert(endingTimeStamp > startingTimestamp)
                resolve()
              } catch (e) {
                console.error(e)
                reject(e)
              }
            })
            console.log("Entering Raffle...")
            const tx = await raffle.enterRaffle({ value: raffleEntranceFee })
            await tx.wait(1)
            console.log("Ok, time to wait...")
            const winnerStartingBalance = await accounts[0].getBalance()
          })
        })
      })
    })
