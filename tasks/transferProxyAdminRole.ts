import { task } from 'hardhat/config'

import { EndpointId } from '@layerzerolabs/lz-definitions'

// TODO: dynamically select testnet or mainnet when mainnet config is added.
import { getOwnerAddress } from '../consts/testnet'

// Toggle to run the task in read or write mode.
let disabled = true

const eidToContractName: Partial<Record<EndpointId, string>> = {
    [EndpointId.SEPOLIA_V2_TESTNET]: 'WXRPToken',
    [EndpointId.HYPERLIQUID_V2_TESTNET]: 'WXRPToken',
}

task('transfer-proxy-admin', 'Transfer proxy admin ownership to multisig address').setAction(async (args, hre) => {
    if (!hre.network.config.eid) throw new Error('Network EID not configured')

    const signer = (await hre.ethers.getSigners())[0]
    const signerAddress = await signer.getAddress()

    const contractName = eidToContractName[hre.network.config.eid]
    if (!contractName) throw new Error(`No contract name mapped for EID ${hre.network.config.eid}`)

    const proxyAdminDeployment = await hre.deployments.get(`${contractName}_ProxyAdmin`)
    const proxyDeployment = await hre.deployments.get(`${contractName}_Proxy`)

    const proxyAdmin = await hre.ethers.getContractAt(proxyAdminDeployment.abi, proxyAdminDeployment.address)

    const proxySetAdmin = await proxyAdmin.getProxyAdmin(proxyDeployment.address)
    if (proxySetAdmin !== proxyAdminDeployment.address) {
        throw new Error(
            `OptimizedTransparentUpgradeableProxy admin is ${proxySetAdmin}, ProxyAdmin is ${proxyAdminDeployment.address}`
        )
    }

    const proxyAdminOwner = await proxyAdmin.owner()

    const ownerAddress = hre.ethers.utils.getAddress(getOwnerAddress(hre.network.config.eid))
    if (ownerAddress.toLowerCase() === signerAddress.toLowerCase()) {
        throw new Error('Intended owner address is the same as signer address, cannot transfer roles')
    }

    if (proxyAdminOwner === ownerAddress) {
        console.log(`ProxyAdmin owner is already intended owner at ${ownerAddress}`)
        return
    }

    console.log(`ProxyAdmin owner is ${proxyAdminOwner}, transferring to intended owner at ${ownerAddress}`)

    if (proxyAdminOwner !== signerAddress) {
        throw new Error(`ProxyAdmin owner is ${proxyAdminOwner}, signer is ${signerAddress}, cannot transfer ownership`)
    }

    if (disabled) throw new Error('Task disabled')

    const tx = await proxyAdmin.transferOwnership(ownerAddress)
    console.log(`Ownership transfer TX sent ${tx.hash}`)
})
