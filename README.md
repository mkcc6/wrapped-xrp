<p align="center">
  <a href="https://layerzero.network">
    <img alt="LayerZero" style="width: 400px" src="https://docs.layerzero.network/img/LayerZero_Logo_Black.svg"/>
  </a>
</p>

<p align="center">
 <a href="https://docs.layerzero.network/" style="color: #a77dff">LayerZero Docs</a>
</p>

<h1 align="center">wXRP Contracts</h1>

## Overview

wXRP token and OFT contracts on Ethereum and HyperEVM.

## Deployment

### Testnet

```bash
# Compile contracts.
pnpm hardhat compile

# Send 0.01 USDC to deployer address on HyperCore through `app.hyperliquid-testnet.xyz`.
# It'll activate the account.

# Ensure the account is activated.
pnpm dlx @layerzerolabs/hyperliquid-composer is-account-activated -u $(cast wallet addr $PRIVATE_KEY) -n testnet

# Deploy OFT contracts. Prompts will appear to confirm HyperEVM block size switching.
pnpm hardhat lz:deploy --networks ethereum-testnet,hyperevm-testnet --tags WXRP --ci

# Wire OFT contracts.
pnpm hardhat lz:oapp:wire --oapp-config layerzero.testnet.config.ts

# Transfer ownership.
pnpm hardhat lz:ownable:transfer-ownership --oapp-config layerzero.testnet.config.ts

# Transfer proxy admin owner.
pnpm hardhat transfer-proxy-admin --network ethereum-testnet
pnpm hardhat transfer-proxy-admin --network hyperevm-testnet

# Transfer ERC20 deault admin role.
pnpm hardhat transfer-erc20-admin --network ethereum-testnet
pnpm hardhat transfer-erc20-admin --network hyperevm-testnet
```

## Caveats

1. HyperEVM testnet has historically experienced frequent and aperiodic shutdowns and inconsistent behaviours. Beware that testing transactions and deployments may be affected by it.
