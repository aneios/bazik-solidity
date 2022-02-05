# Deployment

## HardHat

```sh
npx hardhat node
```

## Mainnet

```sh
npm run mainnet:deploy
```

```sh
npm run mainnet:verify
```

```sh
hardhat tenderly:verify --network mainnet ContractName=Address
```

```sh
hardhat tenderly:push --network mainnet ContractName=Address
```

## Ropsten

```sh
npm run ropsten:deploy
```

```sh
npm run ropsten:verify
```

```sh
hardhat tenderly:verify --network ropsten ContractName=Address
```

## Kovan

```sh
npm run ropsten:deploy
```

```sh
npm run ropsten:verify
```

```sh
hardhat tenderly:verify --network kovan ContractName=Address
```
