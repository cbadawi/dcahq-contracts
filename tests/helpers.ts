import { Cl } from "@stacks/transactions"

export const burnAddress = "SP000000000000000000002Q6VF78"
// fpmm errors
export const ERR_NOT_AUTHORIZED = Cl.uint(9999)
export const ERR_INVALID_AMOUNT = Cl.uint(9001)
export const ERR_INVALID_PRINCIPAL = Cl.uint(9002)
export const ERR_INVALID_INTERVAL = Cl.uint(9003)
export const ERR_INVALID_KEY = Cl.uint(9004)
export const ERR_DCA_ALREADY_EXISTS = Cl.uint(9005)
export const ERR_INVALID_PRICE = Cl.uint(9006)

export const UNIT = 10 ** 8
export const fourPercent = UNIT * 0.04
export const defaultTotalAmount = 1000_00000000
export const defaultDcaAmount = 100_00000000

export const maxUint128Value = 9007199254740991

export const prettyEvents = (events: any, functionName = "") => {
  // console.log({ rawEvents: events })
  return events
    .filter((e: any) => {
      if (!functionName) return true
      return JSON.stringify(e.data.value)?.includes(functionName)
    })
    .map(
      // @ts_ignore
      (e: any) =>
        e.event == "print_event"
          ? {
              value: Cl.prettyPrint(e.data.value),
              contract_identifier: e.data.contract_identifier
            }
          : e
    )
}

export const logResponse = (resp: any, desc?: string) => {
  console.log(
    desc ?? "",
    Cl.prettyPrint(resp.result),
    prettyEvents(resp.events)
  )
}

export const buffFromHex = (id: string) =>
  Cl.buffer(Uint8Array.from(Buffer.from(id, "hex")))

export const accounts = simnet.getAccounts()
export const address1 = accounts.get("wallet_1")! // ST1SJ3DTE5DN7X54YDH5D64R3BCB6A2AG2ZQ8YPD5
export const address2 = accounts.get("wallet_2")! // ST2CY5V39NHDPWSXMW9QDT3HC3GD6Q6XX4CFRK9AG
export const address3 = accounts.get("wallet_3")!
export const address4 = accounts.get("wallet_4")!

export const contractDeployer = "ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM"
export const version = "-v0-0"
export const dcaManagerContract = contractDeployer + ".dca-manager" + version
export const dcaVaultContract = contractDeployer + ".dca-vault" + version
export const authContract = contractDeployer + ".auth" + version
export const defaultStrategyContract =
  contractDeployer + ".default-strategy" + version
export const ammMockContract = contractDeployer + ".mock-alex"
export const shareFeeToContract =
  "SP1Y5YSTAHZ88XYK1VPDH24GY0HPX5J4JECTMY4A1.univ2-share-fee-to"

export const sourceToken = contractDeployer + ".wusd"
export const targetToken = contractDeployer + ".sbtc"
// 6 decimal places
export const wusd6Token = contractDeployer + ".wusd-6"
export const welsh6Token = contractDeployer + ".welsh"

const defaultFactor = 100_000_000

export const defaultSourcesTokenConfig: SourcesTargetConfigsParams = {
  source: sourceToken,
  target: targetToken,
  id: 0,
  feeFixed: 0,
  feePercent: 0,
  sourceFactor: defaultFactor,
  hopFactor: defaultFactor,
  minDcaThreshold: 0,
  maxDcaThreshold: maxUint128Value,
  maxSlipage: fourPercent,
  isSourceNumerator: false,
  token0: sourceToken,
  token1: targetToken,
  tokenIn: sourceToken,
  tokenOut: targetToken
}

export enum INTERVALS {
  hours2,
  daily,
  weekly
}

export const addApproved = (address: string) => {
  return simnet.callPublicFn(
    authContract,
    "add-approved-contract",
    [Cl.principal(address)],
    contractDeployer
  )
}

export const addApprovedDCANetwork = (address: string) => {
  return simnet.callPublicFn(
    authContract,
    "add-approved-dca-network",
    [Cl.principal(address)],
    contractDeployer
  )
}

export const addStrategy = (address: string) => {
  return simnet.callPublicFn(
    dcaManagerContract,
    "set-approved-strategy",
    [Cl.principal(address), Cl.bool(true)],
    contractDeployer
  )
}

type SourcesTargetConfigsParams = {
  source: string
  target: string
  id: number
  feeFixed: number
  feePercent: number
  sourceFactor: number
  hopFactor: number
  minDcaThreshold: number
  maxDcaThreshold: number
  maxSlipage: number
  isSourceNumerator?: boolean
  token0: string
  token1: string
  tokenIn: string
  tokenOut: string
}

export const setSourcesTargetsConfig = ({
  source,
  target,
  id,
  feeFixed,
  feePercent,
  sourceFactor,
  hopFactor,
  minDcaThreshold,
  maxDcaThreshold,
  maxSlipage,
  isSourceNumerator = true,
  token0,
  token1,
  tokenIn,
  tokenOut
}: SourcesTargetConfigsParams) => {
  console.log({ feeFixed })
  return simnet.callPublicFn(
    dcaManagerContract,
    "set-sources-targets-config",
    [
      Cl.principal(source),
      Cl.principal(target),
      Cl.uint(id),
      Cl.uint(feeFixed),
      Cl.uint(feePercent),
      Cl.uint(sourceFactor),
      Cl.uint(hopFactor),
      Cl.bool(isSourceNumerator),
      Cl.uint(minDcaThreshold),
      Cl.uint(maxDcaThreshold),
      Cl.uint(maxSlipage),
      Cl.principal(token0),
      Cl.principal(token1),
      Cl.principal(tokenIn),
      Cl.principal(tokenOut)
    ],
    contractDeployer
  )
}

export const mintSourceToken = (
  recipient = address1,
  mintAmount = defaultTotalAmount,
  source = sourceToken
) => {
  const mintRespone = simnet.callPublicFn(
    source,
    "mint",
    [Cl.uint(mintAmount), Cl.principal(recipient)],
    contractDeployer
  )
  return mintRespone
}

export const createDCA = ({
  address,
  dcaAmount,
  totalAmount,
  minPrice,
  maxPrice,
  interval,
  source,
  target
}: {
  address?: string
  dcaAmount?: number
  totalAmount?: number
  minPrice?: number
  maxPrice?: number
  interval?: number
  source?: string
  target?: string
}) => {
  return simnet.callPublicFn(
    dcaManagerContract,
    "create-dca",
    [
      Cl.principal(source ?? sourceToken),
      Cl.principal(target ?? targetToken),
      Cl.uint(interval ?? INTERVALS.hours2),
      Cl.uint(totalAmount ?? defaultTotalAmount),
      Cl.uint(dcaAmount ?? defaultDcaAmount),
      Cl.uint(minPrice ?? 0),
      Cl.uint(maxPrice ?? maxUint128Value),
      Cl.principal(defaultStrategyContract)
    ],
    address ?? address1
  )
}

export const addToPosition = (params: {
  amount?: number
  source?: string
  target?: string
  interval?: number
}) => {
  const {
    amount = 100_00000000,
    source = sourceToken,
    target = targetToken,
    interval = INTERVALS.hours2
  } = params
  return simnet.callPublicFn(
    dcaManagerContract,
    "add-to-position",
    [
      Cl.principal(source),
      Cl.principal(target),
      Cl.uint(interval),
      Cl.principal(defaultStrategyContract),
      Cl.uint(amount)
    ],
    address1
  )
}

export const reducePosition = (params: {
  amount?: number
  source?: string
  target?: string
  interval?: number
  address?: string
}) => {
  const {
    amount = 50_00000000,
    source = sourceToken,
    target = targetToken,
    interval = INTERVALS.hours2,
    address = address1
  } = params
  return simnet.callPublicFn(
    dcaManagerContract,
    "reduce-position",
    [
      Cl.principal(source),
      Cl.principal(target),
      Cl.uint(interval),
      Cl.principal(defaultStrategyContract),
      Cl.uint(amount)
    ],
    address
  )
}

export const withdraw = (params: {
  amount?: number
  source?: string
  target?: string
  interval?: number
  address?: string
}) => {
  const {
    amount = 200000,
    source = sourceToken,
    target = targetToken,
    interval = INTERVALS.hours2,
    address = address1
  } = params
  return simnet.callPublicFn(
    dcaManagerContract,
    "withdraw",
    [
      Cl.principal(source),
      Cl.principal(target),
      Cl.uint(interval),
      Cl.principal(defaultStrategyContract),
      Cl.uint(amount)
    ],
    address
  )
}

export const dcaUsersA = (
  source: string,
  target: string,
  addresses: string[],
  interval: INTERVALS,
  helperTrait?: string
) => {
  return simnet.callPublicFn(
    dcaManagerContract,
    "dca-users-a",
    [
      Cl.list(
        addresses.map(a =>
          Cl.tuple({
            user: Cl.principal(a),
            source: Cl.principal(source),
            target: Cl.principal(target),
            interval: Cl.uint(interval),
            strategy: Cl.principal(defaultStrategyContract)
          })
        )
      ),
      Cl.principal(defaultStrategyContract),
      Cl.principal(source),
      Cl.principal(target),
      helperTrait ? Cl.principal(helperTrait) : Cl.none()
    ],
    address1
  )
}

export const dcaUsersB = (
  source: string,
  target: string,
  addresses: string[],
  interval: INTERVALS,
  targetAmountOut: number
) => {
  return simnet.callPublicFn(
    dcaManagerContract,
    "dca-users-b",
    [
      Cl.principal(defaultStrategyContract),
      Cl.principal(source),
      Cl.principal(target),
      Cl.principal(source),
      Cl.principal(target),
      Cl.principal(shareFeeToContract),
      Cl.tuple({ "target-amount-out": Cl.uint(targetAmountOut) }),
      Cl.list(
        addresses.map(a =>
          Cl.tuple({
            user: Cl.principal(a),
            source: Cl.principal(source),
            target: Cl.principal(target),
            interval: Cl.uint(interval),
            strategy: Cl.principal(defaultStrategyContract)
          })
        )
      )
    ],
    address1
  )
}

export const getDcaData = (
  user: string,
  source: string,
  target: string,
  interval: INTERVALS
) => {
  const resp = simnet.getMapEntry(
    dcaManagerContract,
    "dca-data",
    Cl.tuple({
      user: Cl.principal(user),
      source: Cl.principal(source),
      target: Cl.principal(target),
      interval: Cl.uint(interval),
      strategy: Cl.principal(defaultStrategyContract)
    })
  )
  // @ts-ignore
  return resp.value?.data
}

export const initDca = (
  address: string,
  id: number,
  totalAmount?: number,
  dcaAmount?: number,
  minPrice?: number,
  maxPrice?: number,
  source = sourceToken,
  target = targetToken,
  isSourceNumerator = false
) => {
  addApproved(contractDeployer)
  addApproved(dcaManagerContract)
  addApproved(ammMockContract)
  addApprovedDCANetwork(address1)
  addApproved(defaultStrategyContract) // only required in test
  addStrategy(defaultStrategyContract)
  setSourcesTargetsConfig({
    source,
    target,
    id,
    feeFixed: 0.005 * 10 ** 8,
    feePercent: 0,
    sourceFactor: defaultFactor,
    hopFactor: 0,
    minDcaThreshold: 0,
    maxDcaThreshold: maxUint128Value,
    maxSlipage: UNIT * 0.5,
    isSourceNumerator,
    token0: source,
    token1: target,
    tokenIn: source,
    tokenOut: target
  })
  mintSourceToken(address, totalAmount, source)
  return createDCA({
    address,
    totalAmount,
    dcaAmount,
    minPrice,
    maxPrice,
    source,
    target
  })
}
