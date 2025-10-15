import { type DeployFunction } from 'hardhat-deploy/types'

import { deployMaba } from './WXRPMintBurnOFTAdapter'
import { deployToken } from './WXRPToken'
import { grantRoles } from './grantRoles'

const tag = 'WXRP'

const deploy: DeployFunction = async (hre) => {
    const token = await deployToken(hre)
    console.log(`WXRPToken proxy admin deployed at ${token.proxyAdminResult.address} on ${hre.network.name}`)
    console.log(`WXRPToken implementation deployed at ${token.implementationResult.address} on ${hre.network.name}`)
    console.log(`WXRPToken proxy deployed at ${token.proxyResult.address} on ${hre.network.name}`)

    const maba = await deployMaba(hre)
    console.log(`WXRPMintBurnOFTAdapter deployed at ${maba.address} on ${hre.network.name}`)

    await grantRoles(hre)
}

deploy.tags = [tag]

export default deploy
