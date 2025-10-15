import { HardhatRuntimeEnvironment } from 'hardhat/types'

export const grantRoles = async (hre: HardhatRuntimeEnvironment) => {
    const eid = hre.network.config.eid
    if (!eid) throw new Error('Network EID is not defined in Hardhat config')

    const mabaName = 'WXRPMintBurnOFTAdapter'
    const mabaDeployment = await hre.deployments.get(mabaName)
    const { address: mabaAddress } = mabaDeployment

    const erc20Name = 'WXRPToken'
    const erc20Deployment = await hre.deployments.get(erc20Name)
    const { address: erc20Address } = erc20Deployment
    const erc20Factory = await hre.ethers.getContractFactory(erc20Name)
    const erc20 = erc20Factory.attach(erc20Address)

    const [minterRole, burnerRole] = await Promise.all([erc20.MINTER_ROLE(), erc20.BURNER_ROLE()])

    const grantRoleIfRequired = async (roleName: string, roleHash: string) => {
        const hasRole = await erc20.hasRole(roleHash, mabaAddress)

        if (hasRole) {
            console.log(`OFT at ${hre.network.name} already has role ${roleName}`)
            return
        }

        console.log(`Granting role ${roleName} for ${hre.network.name}...`)

        const tx = await erc20.grantRole(roleHash, mabaAddress)
        console.log(`Grant ${roleName} role TX send ${tx.hash}`)
    }

    await grantRoleIfRequired('minter', minterRole)
    await grantRoleIfRequired('burner', burnerRole)
}
