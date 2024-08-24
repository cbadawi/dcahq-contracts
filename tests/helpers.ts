import { Cl } from "@stacks/transactions"

// fpmm errors
export const ERR_NOT_AUTHORIZED = Cl.uint(1000)
export const ERR_INVALID_AMOUNT = Cl.uint(2001)
export const ERR_INVALID_PRINCIPAL = Cl.uint(2002)
export const ERR_INVALID_INTERVAL = Cl.uint(2003)
export const ERR_INVALID_KEY = Cl.uint(2004)
export const ERR_DCA_ALREADY_EXISTS = Cl.uint(2005)
export const ERR_INVALID_PRICE = Cl.uint(2006)

export const UNIT = 10 ** 8
export const fourPercent = UNIT * 0.04
export const defaultTotalAmount = 1000_00000000
export const defaultDcaAmount = 100_00000000

const maxUint128Value = 9007199254740991

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

export const contractDeployer = "ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM"
export const dcaRegistryContract = contractDeployer + ".dca-registry"
export const dcaManagerContract = contractDeployer + ".dca-manager"
export const dcaVaultContract = contractDeployer + ".dca-vault"
export const authContract = contractDeployer + ".auth"
export const ammMockContract = contractDeployer + ".mock-alex"
export const defaultStrategyContract = contractDeployer + ".default-strategy"

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
  strategyPrincipal: defaultStrategyContract,
  maxSlipage: fourPercent,
  isSourceNumerator: false
}

export enum INTERVALS {
  hours2,
  hours12,
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
  strategyPrincipal: string
  maxSlipage: number
  isSourceNumerator?: boolean
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
  strategyPrincipal,
  maxSlipage,
  isSourceNumerator = true
}: SourcesTargetConfigsParams) => {
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
      Cl.principal(strategyPrincipal),
      Cl.uint(maxSlipage)
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
      Cl.uint(maxPrice ?? maxUint128Value)
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
}) => {
  const {
    amount = 50_00000000,
    source = sourceToken,
    target = targetToken,
    interval = INTERVALS.hours2
  } = params
  return simnet.callPublicFn(
    dcaManagerContract,
    "reduce-position",
    [
      Cl.principal(source),
      Cl.principal(target),
      Cl.uint(interval),
      Cl.uint(amount)
    ],
    address1
  )
}

export const withdraw = (params: {
  amount?: number
  source?: string
  target?: string
  interval?: number
}) => {
  const {
    amount = 200000,
    source = sourceToken,
    target = targetToken,
    interval = INTERVALS.hours2
  } = params
  return simnet.callPublicFn(
    dcaManagerContract,
    "withdraw",
    [
      Cl.principal(source),
      Cl.principal(target),
      Cl.uint(interval),
      Cl.uint(amount)
    ],
    address1
  )
}

export const dcaUsers = (
  source: string,
  target: string,
  addresses: string[],
  interval: INTERVALS,
  helperTrait?: string
) => {
  return simnet.callPublicFn(
    dcaManagerContract,
    "dca-users",
    [
      Cl.principal(source),
      Cl.principal(target),
      Cl.list(
        addresses.map(a =>
          Cl.tuple({
            user: Cl.principal(a),
            source: Cl.principal(source),
            target: Cl.principal(target),
            interval: Cl.uint(interval)
          })
        )
      ),
      Cl.principal(defaultStrategyContract),
      helperTrait ? Cl.principal(helperTrait) : Cl.none()
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
      interval: Cl.uint(interval)
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
  addApproved(ammMockContract)
  addApproved(dcaManagerContract)
  addApproved(defaultStrategyContract)
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
    strategyPrincipal: defaultStrategyContract,
    maxSlipage: fourPercent,
    isSourceNumerator
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
