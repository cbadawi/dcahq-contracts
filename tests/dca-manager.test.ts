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
  dcaUsersA,
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
  defaultSourcesTokenConfig,
  addStrategy,
  maxUint128Value,
  dcaUsersB,
  address4,
  addApprovedDCANetwork
} from "./helpers"
import { boolCV, Cl } from "@stacks/transactions"

describe.skip("create-dca", () => {
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
    const response = initDca(address1, 0)
    logResponse(response)
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

describe.skip("add-to-position", () => {
  beforeEach(() => {
    addApproved(contractDeployer)
    addApproved(dcaManagerContract)
    setSourcesTargetsConfig(defaultSourcesTokenConfig)
    mintSourceToken()
    addStrategy(defaultStrategyContract)
    logResponse(createDCA({}), "create dca ")
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

describe.skip("reduce-position", () => {
  beforeEach(() => {
    addApproved(contractDeployer)
    addApproved(dcaManagerContract)
    setSourcesTargetsConfig(defaultSourcesTokenConfig)
    mintSourceToken()
    addStrategy(defaultStrategyContract)
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

describe.skip("withdraws", () => {
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

describe.only("dca", () => {
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
    const dcausers = dcaUsersA(
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
  it.skip("one user fails with invalid price while the other passes", () => {
    const resp = dcaUsersA(
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
  it.skip("adds correct fee to treasury", () => {
    const feeAmount = 100000000
    setSourcesTargetsConfig({
      ...defaultSourcesTokenConfig,
      feeFixed: feeAmount
    })
    const resp = dcaUsersA(
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
    const secondResp = dcaUsersA(
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
  it.skip("swaps a source with 8 decimals with a target of 6", () => {
    let sourceUnit = 10 ** 8
    let targetUnit = 10 ** 6
    const totalAmount = 1000 * sourceUnit
    const dcaAmount = 100 * sourceUnit
    const minPrice = 0.001 * 10 ** 8
    const maxPrice = 0.003 * 10 ** 8
    initDca(
      address3,
      0,
      totalAmount,
      dcaAmount,
      minPrice,
      maxPrice,
      wusd6Token,
      welsh6Token,
      false
    )
    const resp = dcaUsersA(
      wusd6Token,
      welsh6Token,
      [address3],
      INTERVALS.hours2
    )
    logResponse(resp)
    const event = Cl.prettyPrint(resp.events[2].data.value!)
    const priceMatch = event.match(/, price:\s*u(\d+)/)
    const price = priceMatch?.at(1)
    expect(Number(price) / 10 ** 8).toBeGreaterThan(0.0015)
    expect(Number(price) / 10 ** 8).toBeLessThan(0.0016)
  })
  it.skip("swaps a source with 6 decimals with a target of 8", () => {
    let sourceUnit = 10 ** 6
    let targetUnit = 10 ** 8
    const totalAmount = 1000 * sourceUnit
    const dcaAmount = 100 * sourceUnit
    const minPrice = 0.001 * 10 ** 8
    const maxPrice = 0.003 * 10 ** 8
    initDca(
      address3,
      0,
      totalAmount,
      dcaAmount,
      minPrice,
      maxPrice,
      wusd6Token,
      welsh6Token,
      false
    )
    const resp = dcaUsersA(
      wusd6Token,
      welsh6Token,
      [address3],
      INTERVALS.hours2
    )
    const event = Cl.prettyPrint(resp.events[4].data.value!)
    const priceMatch = event.match(/, price:\s*u(\d+)/)
    const price = priceMatch?.at(1)
    expect(Number(price) / 10 ** 8).toBeGreaterThan(0.0015)
    expect(Number(price) / 10 ** 8).toBeLessThan(0.0016)
  })
})

describe("security tests", () => {
  beforeEach(() => {
    const initresp = initDca(address1, 0)
    logResponse(initresp, "initresp ")
    const dcauserss = dcaUsersA(
      sourceToken,
      targetToken,
      [address1],
      INTERVALS.hours2
    )
    logResponse(dcauserss, "dca users ")
  })

  it("prevents unauthorized withdraw", () => {
    const amount = 100_00000000
    mintSourceToken(address1, amount)
    const resp = withdraw({
      amount,
      source: sourceToken,
      target: targetToken,
      interval: INTERVALS.hours2,
      address: address2
    })
    expect(resp.result).toBeErr(ERR_INVALID_KEY)
  })

  it("prevents unauthorized reduce position", () => {
    const amount = 100_00000000
    // mintSourceToken(address1, amount)
    const resp = reducePosition({
      amount,
      source: sourceToken,
      target: targetToken,
      interval: INTERVALS.hours2,
      address: address2
    })
    logResponse(resp)
    expect(resp.result).toBeErr(ERR_INVALID_KEY)
  })

  it("allows authorized withdraw", () => {
    const amount = defaultTotalAmount
    const resp = withdraw({
      amount,
      source: sourceToken,
      target: targetToken,
      interval: INTERVALS.hours2,
      address: address1
    })

    logResponse(resp)
    expect(resp.result).toStrictEqual(Cl.ok(Cl.bool(true)))
  })

  it("allows authorized reduce position", () => {
    const resp = reducePosition({
      source: sourceToken,
      target: targetToken,
      interval: INTERVALS.hours2,
      address: address1
    })
    logResponse(resp, "reduce position")
    expect(resp.result).toStrictEqual(Cl.ok(Cl.bool(true)))
  })
})

describe("set-new-target-amount", () => {
  beforeEach(() => {
    initDca(address1, 0)
    initDca(address2, 0, 2000_00000000, 200_00000000)
    initDca(address3, 0, 1000_00000000, 100_00000000, maxUint128Value)
  })

  it("updates target-amount and source-amount-left correctly", () => {
    const dcausersResp = dcaUsersA(
      sourceToken,
      targetToken,
      [address1, address2],
      INTERVALS.hours2
    )

    logResponse(dcausersResp, "dca users")

    const dcaDataAddress1 = getDcaData(
      address1,
      sourceToken,
      targetToken,
      INTERVALS.hours2
    )

    const dcaDataAddress2 = getDcaData(
      address2,
      sourceToken,
      targetToken,
      INTERVALS.hours2
    )

    console.log({ dcaDataAddress1, dcaDataAddress2 })

    // Check that `target-amount` is updated correctly
    expect(dcaDataAddress1["target-amount"].value).toBeGreaterThan(0)
    expect(dcaDataAddress2["target-amount"].value).toBeGreaterThan(0)

    // Check that `source-amount-left` is reduced correctly
    expect(dcaDataAddress1["source-amount-left"].value).toBeLessThan(
      1000_00000000
    )
    expect(dcaDataAddress2["source-amount-left"].value).toBeLessThan(
      2000_00000000
    )

    console.log({ dcaDataAddress2, dcaDataAddress1 })
    // Ensure `last-updated-timestamp` is updated
    expect(dcaDataAddress1["last-updated-timestamp"]).toBeDefined()
    expect(dcaDataAddress2["last-updated-timestamp"]).toBeDefined()
  })
  it("fails for invalid price while updating the second user", () => {
    // Simulate different price scenarios for different users
    const dcausersResp = dcaUsersA(
      sourceToken,
      targetToken,
      [address1, address3],
      INTERVALS.hours2
    )

    logResponse(dcausersResp, "dca users with invalid price")

    const [firstUserResponse, secondUserResponse] =
      // @ts-ignore
      dcausersResp.result.value.list

    // First user should succeed
    expect(firstUserResponse.value).toBeGreaterThan(0)

    // Second user should fail due to invalid price
    expect(Number(secondUserResponse.value)).toBe(0)
  })
})

describe("velar", () => {
  beforeEach(() => {
    const poolid = 10
    const address1resp = initDca(
      address1,
      poolid,
      1000 * 10 ** 6,
      100 * 10 ** 6,
      0,
      999999999999999,
      wusd6Token,
      welsh6Token,
      false
    )
    const address2resp = initDca(
      address2,
      poolid,
      200 * 10 ** 6,
      20 * 10 ** 6,
      0,
      999999999999999,
      wusd6Token,
      welsh6Token,
      false
    )
    const address3resp = initDca(
      address3,
      poolid,
      300 * 10 ** 6,
      30 * 10 ** 6,
      0,
      0,
      wusd6Token,
      welsh6Token,
      false
    )
  })
  it("updates source & target in dca-data map", () => {
    const targetAmount = 1000
    const dcausers = dcaUsersB(
      wusd6Token,
      welsh6Token,
      [address1],
      INTERVALS.hours2,
      targetAmount
    )

    const dcaData = getDcaData(
      address1,
      wusd6Token,
      welsh6Token,
      INTERVALS.hours2
    )
    expect(dcaData["source-amount-left"]).toStrictEqual(
      Cl.uint((defaultTotalAmount - defaultDcaAmount) / 10 ** 2)
    )
    expect(dcaData["target-amount"].value).toBeGreaterThan(0)
  })

  it("one user fails with invalid price while the other passes", () => {
    const resp = dcaUsersB(
      wusd6Token,
      welsh6Token,
      [address1, address3],
      INTERVALS.hours2,
      100000
    )
    logResponse(resp, "dca users")
    // @ts-ignore
    const [firstResp, secondResp] = resp.result.value.list
    expect(firstResp.value).toBeGreaterThan(0)
    expect(Number(secondResp.value)).toBe(0) // invalid price
  })

  it("adds correct fee to treasury", () => {
    const feeAmount = 1000000 // 1 usd
    const setSourcesTargetsConfigresp = setSourcesTargetsConfig({
      ...defaultSourcesTokenConfig,
      source: wusd6Token,
      target: welsh6Token,
      feeFixed: feeAmount
    })
    logResponse(setSourcesTargetsConfigresp, "setSourcesTargetsConfigresp")
    const resp = dcaUsersB(
      wusd6Token,
      welsh6Token,
      [address1, address2, address3],
      INTERVALS.hours2,
      100000
    )
    const fee = simnet.callReadOnlyFn(
      dcaManagerContract,
      "get-fee",
      [Cl.principal(wusd6Token)],
      address2
    )
    logResponse(resp, "first dca")
    console.log({ fee })
    // @ts-ignore
    const fixedFeeValue = fee.result.value as bigint
    expect(fixedFeeValue).toBe(BigInt(feeAmount * 2))

    simnet.mineEmptyBlocks(10)
    const feePercentage = 5 * 100000
    const expectedFeePercAmount = (defaultDcaAmount * feePercentage) / 10 ** 8
    setSourcesTargetsConfig({
      ...defaultSourcesTokenConfig,
      feeFixed: feeAmount,
      feePercent: feePercentage,
      source: wusd6Token,
      target: welsh6Token
    })
    const secondResp = dcaUsersB(
      wusd6Token,
      welsh6Token,
      [address1],
      INTERVALS.hours2,
      10000
    )
    const totalFee = simnet.callReadOnlyFn(
      dcaManagerContract,
      "get-fee",
      [Cl.principal(wusd6Token)],
      address2
    )
    const expectedTotalFee =
      Number(fixedFeeValue) + feeAmount + expectedFeePercAmount
    logResponse(secondResp, "second dca")
    // @ts-ignore
    const finalFeeValue = totalFee.result.value as bigint
    expect(Number(finalFeeValue)).toBe(expectedTotalFee)
  })
})
