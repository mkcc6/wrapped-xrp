import { HardhatRuntimeEnvironment } from 'hardhat/types'

export function loadHreWallet(hre: HardhatRuntimeEnvironment, index: number = 0) {
    const accounts = hre.network.config.accounts
    if (!accounts) throw new Error('Accounts are not defined in Hardhat config')
    if (Array.isArray(accounts) && accounts[index]) {
        const account = accounts[index]
        const pk = typeof account === 'string' ? account : account.privateKey
        return new hre.ethers.Wallet(pk, hre.ethers.provider)
    } else if (accounts instanceof Object && 'mnemonic' in accounts) {
        return hre.ethers.Wallet.fromMnemonic(accounts.mnemonic).connect(hre.ethers.provider)
    } else {
        throw new Error('Accounts not supported')
    }
}
