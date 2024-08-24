import { beforeEach, describe, expect, it } from "vitest"
import {
  addApproved,
  address1,
  address2,
  addToPosition,
  contractDeployer,
  createDCA,
  getDcaData,
  dcaManagerContract,
  dcaUsers,
  dcaVaultContract,
  ERR_INVALID_AMOUNT,
  ERR_INVALID_INTERVAL,
  ERR_INVALID_KEY,
  ERR_INVALID_PRINCIPAL,
  ERR_NOT_AUTHORIZED,
  initDca,
  INTERVALS,
  logResponse,
  mintSourceToken,
  reducePosition,
  sourceToken,
  targetToken,
  withdraw,
  defaultTotalAmount,
  defaultDcaAmount,
  UNIT,
  ERR_INVALID_PRICE,
  setSourcesTargetsConfig,
  address3,
  welsh6Token,
  wusd6Token,
  defaultStrategyContract,
  defaultSourcesTokenConfig
} from "./helpers"
import { Cl } from "@stacks/transactions"

describe("create-dca", () => {
  it("fails auth", () => {
    const response = setSourcesTargetsConfig(defaultSourcesTokenConfig)
    logResponse(response, "")
    expect(response.result).toBeErr(ERR_NOT_AUTHORIZED)
  })

  it("fails with invalid principal", () => {
    addApproved(contractDeployer)
    addApproved(dcaManagerContract)
    const response = createDCA({})
    expect(response.result).toBeErr(ERR_INVALID_PRINCIPAL)
  })

  it("fails with invalid interval", () => {
    addApproved(contractDeployer)
    addApproved(dcaManagerContract)
    setSourcesTargetsConfig(defaultSourcesTokenConfig)
    const response = createDCA({
      interval: 5,
      totalAmount: 9999999,
      dcaAmount: 99999
    })
    expect(response.result).toBeErr(ERR_INVALID_INTERVAL)
  })

  it("creates dca entry", () => {
    addApproved(contractDeployer)
    addApproved(dcaManagerContract)
    setSourcesTargetsConfig(defaultSourcesTokenConfig)
    mintSourceToken()
    const response = createDCA({})
    expect(
      response.events.filter(e => e.event === "ft_transfer_event")[0]?.data
        .recipient
    ).toBe(dcaVaultContract)

    const dcaEntry = getDcaData(
      address1,
      sourceToken,
      targetToken,
      INTERVALS.hours2
    )
    expect(dcaEntry.amount).toStrictEqual(Cl.uint(100_00000000))
  })
})

describe("add-to-position", () => {
  beforeEach(() => {
    addApproved(contractDeployer)
    addApproved(dcaManagerContract)
    setSourcesTargetsConfig(defaultSourcesTokenConfig)
    mintSourceToken()
    createDCA({})
  })
  it("fails on an invalid position", () => {
    const amount = 100_00000000
    mintSourceToken(address1, 100_00000000)
    const resp = addToPosition({ amount, source: targetToken })
    expect(resp.result).toBeErr(ERR_INVALID_KEY)
  })

  it("addds to position", () => {
    const amount = 100_00000000
    mintSourceToken(address1, 100_00000000)
    const resp = addToPosition({ amount })
    const dcaEntry = getDcaData(
      address1,
      sourceToken,
      targetToken,
      INTERVALS.hours2
    )
    expect(dcaEntry["source-amount-left"]).toStrictEqual(Cl.uint(1100_00000000))
  })
})

describe("reduce-position", () => {
  beforeEach(() => {
    addApproved(contractDeployer)
    addApproved(dcaManagerContract)
    setSourcesTargetsConfig(defaultSourcesTokenConfig)
    mintSourceToken()
    createDCA({})
  })
  it("fails on an invalid position", () => {
    const resp = reducePosition({ source: targetToken })
    expect(resp.result).toBeErr(ERR_INVALID_KEY)
  })

  it("reduces position", () => {
    const resp = reducePosition({})
    logResponse(resp, "reduce posi")
    const dcaEntry = getDcaData(
      address1,
      sourceToken,
      targetToken,
      INTERVALS.hours2
    )
    expect(dcaEntry["source-amount-left"]).toStrictEqual(Cl.uint(950_00000000))
  })

  it("reduces just the position even if agreater amount is passed", () => {
    reducePosition({})
    const resp = reducePosition({ amount: 99999999999999 })
    logResponse(resp, "reduce posi")
    const dcaEntry = getDcaData(
      address1,
      sourceToken,
      targetToken,
      INTERVALS.hours2
    )
    expect(dcaEntry["source-amount-left"]).toStrictEqual(Cl.uint(0))
    expect(
      resp.events.filter(e => e.event === "ft_transfer_event")[0]?.data.amount
    ).toBe("95000000000")
  })
})

describe("withdraws", () => {
  beforeEach(() => {
    initDca(address1, 0)
  })

  it("fails when theres nothing to withdraw", () => {
    const resp = withdraw({})
    expect(resp.result).toBeErr(ERR_INVALID_AMOUNT)
  })

  // todo
  it("withdraws after dca'ing", () => {})
})

describe("dca", () => {
  beforeEach(() => {
    initDca(address1, 0)
    initDca(
      address2,
      0,
      defaultTotalAmount,
      defaultDcaAmount,
      9999999 * UNIT,
      9999999 * UNIT
    )
    initDca(address3, 0)
  })

  it("updates source & target in dca-data map", () => {
    const dcausers = dcaUsers(
      sourceToken,
      targetToken,
      [address1],
      INTERVALS.hours2
    )

    logResponse(dcausers, "dcausers")
    const dcaData = getDcaData(
      address1,
      sourceToken,
      targetToken,
      INTERVALS.hours2
    )
    expect(dcaData["source-amount-left"]).toStrictEqual(
      Cl.uint(defaultTotalAmount - defaultDcaAmount)
    )
    expect(dcaData["target-amount"].value).toBeGreaterThan(0)
  })

  it("one user fails with invalid price while the other passes", () => {
    const resp = dcaUsers(
      sourceToken,
      targetToken,
      [address1, address2],
      INTERVALS.hours2
    )
    logResponse(resp, "dca users")
    // @ts-ignore
    const [firstResp, secondResp] = resp.result.value.list
    console.log({
      firstResp: firstResp,
      secondResp: secondResp
    })
    expect(firstResp.value).toBeGreaterThan(0)
    expect(Number(secondResp.value)).toBe(0) // invalid price
  })

  it("adds correct fee to treasury", () => {
    const feeAmount = 100000000
    setSourcesTargetsConfig({
      ...defaultSourcesTokenConfig,
      feeFixed: feeAmount
    })
    const resp = dcaUsers(
      sourceToken,
      targetToken,
      [address1, address2, address3],
      INTERVALS.hours2
    )
    const fee = simnet.callReadOnlyFn(
      dcaManagerContract,
      "get-fee",
      [Cl.principal(sourceToken)],
      address2
    )
    logResponse(resp, "first dca")
    // @ts-ignore
    const fixedFeeValue = fee.result.value as bigint
    expect(fixedFeeValue).toBe(BigInt(feeAmount * 2)) // address1 & address3

    simnet.mineEmptyBlocks(10)
    const feePercentage = 5 * 100000
    const expectedFeePercAmount = (defaultDcaAmount * feePercentage) / 10 ** 8
    setSourcesTargetsConfig({
      ...defaultSourcesTokenConfig,
      feeFixed: feeAmount,
      feePercent: feePercentage
    })
    const secondResp = dcaUsers(
      sourceToken,
      targetToken,
      [address1],
      INTERVALS.hours2
    )
    const totalFee = simnet.callReadOnlyFn(
      dcaManagerContract,
      "get-fee",
      [Cl.principal(sourceToken)],
      address2
    )
    const expectedTotalFee =
      Number(fixedFeeValue) + feeAmount + expectedFeePercAmount
    logResponse(secondResp, "second dca")
    // @ts-ignore
    const finalFeeValue = totalFee.result.value as bigint
    expect(Number(finalFeeValue)).toBe(expectedTotalFee)
  })

  // it("swaps a source with 8 decimals with a target of 6", () => {
  //   let sourceUnit = 10 ** 8
  //   let targetUnit = 10 ** 6
  //   const totalAmount = 1000 * sourceUnit
  //   const dcaAmount = 100 * sourceUnit
  //   const minPrice = 0.001 * 10 ** 8
  //   const maxPrice = 0.003 * 10 ** 8
  //   initDca(
  //     address3,
  //     0,
  //     totalAmount,
  //     dcaAmount,
  //     minPrice,
  //     maxPrice,
  //     wusd6Token,
  //     welsh6Token,
  //     false
  //   )

  //   const resp = dcaUsers(wusd6Token, welsh6Token, [address3], INTERVALS.hours2)
  //   logResponse(resp)
  //   const event = Cl.prettyPrint(resp.events[2].data.value!)
  //   const priceMatch = event.match(/, price:\s*u(\d+)/)

  //   const price = priceMatch?.at(1)
  //   expect(Number(price) / 10 ** 8).toBeGreaterThan(0.0015)
  //   expect(Number(price) / 10 ** 8).toBeLessThan(0.0016)
  // })

  // it("swaps a source with 6 decimals with a target of 8", () => {
  //   let sourceUnit = 10 ** 6
  //   let targetUnit = 10 ** 8
  //   const totalAmount = 1000 * sourceUnit
  //   const dcaAmount = 100 * sourceUnit
  //   const minPrice = 0.001 * 10 ** 8
  //   const maxPrice = 0.003 * 10 ** 8
  //   initDca(
  //     address3,
  //     0,
  //     totalAmount,
  //     dcaAmount,
  //     minPrice,
  //     maxPrice,
  //     wusd6Token,
  //     welsh6Token,
  //     false
  //   )

  //   const resp = dcaUsers(wusd6Token, welsh6Token, [address3], INTERVALS.hours2)

  //   const event = Cl.prettyPrint(resp.events[4].data.value!)
  //   const priceMatch = event.match(/, price:\s*u(\d+)/)
  //   const price = priceMatch?.at(1)
  //   expect(Number(price) / 10 ** 8).toBeGreaterThan(0.0015)
  //   expect(Number(price) / 10 ** 8).toBeLessThan(0.0016)
  // })
})
