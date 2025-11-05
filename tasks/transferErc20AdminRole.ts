import { task } from 'hardhat/config'

import { EndpointId } from '@layerzerolabs/lz-definitions'

import { getOwnerAddress as getMainnetOwnerAddress } from '../consts/mainnet'
import { getOwnerAddress as getTestnetOwnerAddress } from '../consts/testnet'
import { promptForConfirmationOrExit } from '../utils/prompts'

const contractName = 'WXRPToken'

task('transfer-erc20-admin', 'Transfer ERC20 default admin role to multisig address').setAction(async (args, hre) => {
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

    const erc20Deployment = await hre.deployments.get(contractName)
    const erc20 = await hre.ethers.getContractAt(erc20Deployment.abi, erc20Deployment.address)

    const defaultAdminRole = await erc20.DEFAULT_ADMIN_ROLE()

    const grantIntendedOwnerDefaultAdminRoleIfRequired = async () => {
        const isIntendedOwnerDefaultAdmin = await erc20.hasRole(defaultAdminRole, intendedOwnerAddress)
        if (isIntendedOwnerDefaultAdmin) {
            console.log(`Intended owner at ${intendedOwnerAddress} is already default admin`)
            return
        }

        console.log(
            `Intended owner at ${intendedOwnerAddress} is not default admin, granting role from ${signerAddress}`
        )

        const isSignerDefaultAdmin = await erc20.hasRole(defaultAdminRole, signerAddress)
        if (!isSignerDefaultAdmin) {
            throw new Error(`Signer ${signerAddress} is not default admin`)
        }

        await promptForConfirmationOrExit()

        const tx = await erc20.grantRole(defaultAdminRole, intendedOwnerAddress)
        console.log(`Intended owner default admin grant TX sent ${tx.hash}`)
        await tx.wait()
        console.log(`Intended owner default admin grant TX confirmed`)
    }

    await grantIntendedOwnerDefaultAdminRoleIfRequired()

    const renounceSignerDefaultAdminRoleIfRequired = async () => {
        const isSignerDefaultAdmin = await erc20.hasRole(defaultAdminRole, signerAddress)
        if (!isSignerDefaultAdmin) {
            console.log(`Signer at ${signerAddress} is not default admin, nothing to renounce`)
            return
        }

        const isIntendedOwnerDefaultAdmin = await erc20.hasRole(defaultAdminRole, intendedOwnerAddress)
        if (!isIntendedOwnerDefaultAdmin) {
            console.log(`Intended owner at ${intendedOwnerAddress} is not default admin, cannot renounce role`)
            return
        }

        console.log(
            `Both signer at ${signerAddress} and intended owner at ${intendedOwnerAddress} are default admins, renouncing signer role`
        )

        await promptForConfirmationOrExit()

        const tx = await erc20.renounceRole(defaultAdminRole, signerAddress)
        console.log(`Signer default admin renounce TX sent ${tx.hash}`)
        await tx.wait()
        console.log(`Signer default admin renounce TX confirmed`)
    }

    await renounceSignerDefaultAdminRoleIfRequired()
})
