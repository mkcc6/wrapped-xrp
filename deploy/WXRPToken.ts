import { HardhatRuntimeEnvironment } from 'hardhat/types'
import { DeployFunction } from 'hardhat-deploy/types'

import { EndpointId } from '@layerzerolabs/lz-definitions'
import { useBigBlock, useSmallBlock } from '@layerzerolabs/hyperliquid-composer'

import { loadHreWallet } from '../utils/wallet'

const contractName = 'WXRPToken'

export const deployToken = async (hre: HardhatRuntimeEnvironment) => {
    const { deploy } = hre.deployments
    const signer = (await hre.ethers.getSigners())[0]
    console.log(`Deploying ${contractName} on network: ${hre.network.name} with ${signer.address}`)

    const eid = hre.network.config.eid
    if (!eid) throw new Error('Network EID is not defined in Hardhat config')

    const isHyperEvmTestnet = eid === EndpointId.HYPERLIQUID_V2_TESTNET
    const isHyperEvmMainnet = eid === EndpointId.HYPERLIQUID_V2_MAINNET
    const isHyperEvm = isHyperEvmTestnet || isHyperEvmMainnet

    const wallet = isHyperEvm ? loadHreWallet(hre) : undefined
    const logLevel = hre.hardhatArguments.verbose ? 'debug' : 'error'

    const proxyAdminContract = await import('hardhat-deploy/extendedArtifacts/ProxyAdmin.json')
    const proxyContract = await import('hardhat-deploy/extendedArtifacts/OptimizedTransparentUpgradeableProxy.json')

    const proxyAdminName = `${contractName}_ProxyAdmin`
    const proxyAdminResult = await deploy(proxyAdminName, {
        from: signer.address,
        contract: proxyAdminContract,
        args: [signer.address],
        log: true,
        waitConfirmations: 1,
        skipIfAlreadyDeployed: true,
    })
    const { address: proxyAdminAddress } = proxyAdminResult

    // This contract requires >1.5M gas to deploy. Switching to big blocks in HyperEVM.
    const implementationDeployment = await hre.deployments.getOrNull(contractName)
    if (isHyperEvm && !implementationDeployment) await useBigBlock(wallet!, isHyperEvmTestnet, logLevel)

    const implementationName = `${contractName}_Implementation`
    const implementationResult = await deploy(implementationName, {
        from: signer.address,
        contract: contractName,
        args: [],
        log: true,
        waitConfirmations: 1,
        skipIfAlreadyDeployed: true,
    })
    const { address: implementationAddress } = implementationResult

    if (isHyperEvm && !implementationDeployment) await useSmallBlock(wallet!, isHyperEvmTestnet, logLevel)

    const proxyName = `${contractName}_Proxy`
    const initializeInterface = new hre.ethers.utils.Interface(['function initialize(address _admin)'])
    const initializeData = initializeInterface.encodeFunctionData('initialize', [signer.address])
    const proxyResult = await deploy(proxyName, {
        from: signer.address,
        contract: proxyContract,
        args: [implementationAddress, proxyAdminAddress, initializeData],
        log: true,
        waitConfirmations: 1,
        skipIfAlreadyDeployed: true,
    })

    const existing = await hre.deployments.getOrNull(contractName)
    if (!existing) {
        const proxyDeployment = await hre.deployments.get(proxyName)
        const implementationDeployment = await hre.deployments.get(implementationName)
        const deployment = {
            ...proxyDeployment,
            abi: implementationDeployment.abi,
        }
        await hre.deployments.save(contractName, deployment)
    }

    return { proxyAdminResult, implementationResult, proxyResult }
}

export const deploy: DeployFunction = async (hre) => {
    await deployToken(hre)
}

deploy.tags = [contractName]

export default deploy
