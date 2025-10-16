import { EndpointId } from '@layerzerolabs/lz-definitions'
import { ExecutorOptionType } from '@layerzerolabs/lz-v2-utilities'
import { OAppEnforcedOption } from '@layerzerolabs/toolbox-hardhat'

export const OPTIONAL_DVNS: Record<string, Partial<Record<EndpointId, string>>> = {
    CANARY: {
        [EndpointId.ETHEREUM_V2_MAINNET]: '0xa4fe5a5b9a846458a70cd0748228aed3bf65c2cd',
        [EndpointId.HYPERLIQUID_V2_MAINNET]: '0x83342ec538df0460e730a8f543fe63063e2d44c4',
    },
    DEUTSCHE_TELEKOM: {
        [EndpointId.ETHEREUM_V2_MAINNET]: '0x373a6e5c0c4e89e24819f00aa37ea370917aaff4',
        [EndpointId.HYPERLIQUID_V2_MAINNET]: '0x32ffd21260172518a8844fec76a88c8f239c384b',
    },
    LUGANODES: {
        [EndpointId.ETHEREUM_V2_MAINNET]: '0x58249a2ec05c1978bf21df1f5ec1847e42455cf4',
        [EndpointId.HYPERLIQUID_V2_MAINNET]: '0x9e451905f65ef78d62b93dac3513486da8429d0a',
    },
    P2P: {
        [EndpointId.ETHEREUM_V2_MAINNET]: '0x06559ee34d85a88317bf0bfe307444116c631b67',
        [EndpointId.HYPERLIQUID_V2_MAINNET]: '0xc7423626016bc40375458bc0277f28681ec91c8e',
    },
}

export const OPTIONAL_DVNS_THRESHOLD = 2

// Chain default confirmations.
export const CONFIRMATIONS: Partial<Record<EndpointId, number>> = {
    [EndpointId.ETHEREUM_V2_MAINNET]: 15,
    [EndpointId.HYPERLIQUID_V2_MAINNET]: 1,
}

const DEFAULT_ENFORCED_OPTIONS: OAppEnforcedOption[] = [
    { msgType: 1, optionType: ExecutorOptionType.LZ_RECEIVE, gas: 100_000, value: 0 },
    { msgType: 2, optionType: ExecutorOptionType.LZ_RECEIVE, gas: 100_000, value: 0 },
]

// Define enforced options per specific endpoint ID.
export const ENFORCED_OPTIONS: Partial<Record<EndpointId, OAppEnforcedOption[]>> = {
    [EndpointId.ETHEREUM_V2_MAINNET]: DEFAULT_ENFORCED_OPTIONS,
    [EndpointId.HYPERLIQUID_V2_MAINNET]: DEFAULT_ENFORCED_OPTIONS,
}

export const OWNERS: Partial<Record<EndpointId, string>> = {
    [EndpointId.ETHEREUM_V2_MAINNET]: '0xfA633B67b1d9371eBa32cf3476F275D75C75ce77',
    [EndpointId.HYPERLIQUID_V2_MAINNET]: '0xfA633B67b1d9371eBa32cf3476F275D75C75ce77',
} as const

export const getRequiredDVNs = (_eid: EndpointId): string[] => {
    return [] as string[]
}

export const getOptionalDVNs = (eid: EndpointId): string[] => {
    return Object.values(OPTIONAL_DVNS)
        .map((dvnMap) => dvnMap[eid])
        .filter(Boolean) as string[]
}

export const getEnforcedOptions = (eid: EndpointId): OAppEnforcedOption[] => {
    return ENFORCED_OPTIONS[eid] ?? DEFAULT_ENFORCED_OPTIONS
}

export const getOwnerAddress = (eid: EndpointId): string => {
    const address = OWNERS[eid]
    if (!address || address === 'TODO' || address === '0x0000000000000000000000000000000000000000') {
        throw new Error(`Owner address not configured for endpoint ${eid}`)
    }
    return address
}
