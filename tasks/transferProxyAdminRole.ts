import { task } from 'hardhat/config'

import { EndpointId } from '@layerzerolabs/lz-definitions'

import { getOwnerAddress as getMainnetOwnerAddress } from '../consts/mainnet'
import { getOwnerAddress as getTestnetOwnerAddress } from '../consts/testnet'
import { promptForConfirmationOrExit } from '../utils/prompts'

const contractName = 'WXRPToken'

task('transfer-proxy-admin', 'Transfer proxy admin ownership to multisig address').setAction(async (args, hre) => {
    if (!hre.network.config.eid) throw new Error('Network EID not configured')

    const isTestnet =
        hre.network.config.eid === EndpointId.SEPOLIA_V2_TESTNET ||
        hre.network.config.eid === EndpointId.HYPERLIQUID_V2_TESTNET

    const signer = (await hre.ethers.getSigners())[0]
    const signerAddress = await signer.getAddress()

    const intendedOwnerAddressRaw = isTestnet
        ? getTestnetOwnerAddress(hre.network.config.eid)
        : getMainnetOwnerAddress(hre.network.config.eid)
    const intendedOwnerAddress = hre.ethers.utils.getAddress(intendedOwnerAddressRaw)
    if (intendedOwnerAddress.toLowerCase() === signerAddress.toLowerCase()) {
        throw new Error(`Intended owner address is the same as signer address, cannot transfer roles`)
    }

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

    if (proxyAdminOwner === intendedOwnerAddress) {
        console.log(`ProxyAdmin owner is already intended owner at ${intendedOwnerAddress}`)
        return
    }

    console.log(`ProxyAdmin owner is ${proxyAdminOwner}, transferring to intended owner at ${intendedOwnerAddress}`)

    if (proxyAdminOwner !== signerAddress) {
        throw new Error(`ProxyAdmin owner is ${proxyAdminOwner}, signer is ${signerAddress}, cannot transfer ownership`)
    }

    await promptForConfirmationOrExit()

    const tx = await proxyAdmin.transferOwnership(intendedOwnerAddress)
    console.log(`Ownership transfer TX sent ${tx.hash}`)
    await tx.wait()
    console.log(`Ownership transfer TX confirmed`)
})
