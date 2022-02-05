// hardhat.config.ts

import "@nomiclabs/hardhat-ethers";
import "@nomiclabs/hardhat-etherscan";
import "@nomiclabs/hardhat-solhint";
import "@nomiclabs/hardhat-waffle";
import "@openzeppelin/hardhat-defender";
import "@tenderly/hardhat-tenderly";
import "@typechain/hardhat";
import "dotenv/config";
import "hardhat-abi-exporter";
import "hardhat-deploy";
import "hardhat-deploy-ethers";
import "hardhat-gas-reporter";
import "hardhat-spdx-license-identifier";
import "hardhat-watcher";
import "solidity-coverage";
import "./tasks";

import {HardhatUserConfig} from "hardhat/types";
import {removeConsoleLog} from "hardhat-preprocessor";

const accounts = {
	mnemonic: process.env.MNEMONIC || "test test test test test test test test test test test junk"
	// accountsBalance: "990000000000000000000",
};

const config: HardhatUserConfig = {
	defaultNetwork: "hardhat",
	networks: {
		mainnet: {
			url: process.env.ETHEREUM_RPC_URL as string,
			accounts,
			gasPrice: 120 * 1000000000,
			chainId: 1
		},
		localhost: {
			live: false,
			saveDeployments: true,
			tags: ["local"]
		},
		hardhat: {
			forking: {
				enabled: process.env.FORKING === "true",
				url: process.env.ETHEREUM_RPC_URL as string
			},
			live: false,
			saveDeployments: true,
			tags: ["test", "local"]
		},
		kovan: {
			url: process.env.KOVAN_RPC_URL as string,
			accounts,
			chainId: 42,
			live: true,
			saveDeployments: true,
			tags: ["staging"],
			gasPrice: 20000000000,
			gasMultiplier: 2
		},
		moonbase: {
			url: "https://rpc.testnet.moonbeam.network",
			accounts,
			chainId: 1287,
			live: true,
			saveDeployments: true,
			tags: ["staging"],
			gas: 5198000,
			gasMultiplier: 2
		},
		fantom: {
			url: "https://rpcapi.fantom.network",
			accounts,
			chainId: 250,
			live: true,
			saveDeployments: true,
			gasPrice: 22000000000
		},
		"fantom-testnet": {
			url: "https://rpc.testnet.fantom.network",
			accounts,
			chainId: 4002,
			live: true,
			saveDeployments: true,
			tags: ["staging"],
			gasMultiplier: 2
		},
		matic: {
			url: "https://rpc-mainnet.maticvigil.com",
			accounts,
			chainId: 137,
			live: true,
			saveDeployments: true
		},
		mumbai: {
			url: "https://rpc-mumbai.maticvigil.com/",
			accounts,
			chainId: 80001,
			live: true,
			saveDeployments: true,
			tags: ["staging"],
			gasMultiplier: 2
		},
		xdai: {
			url: "https://rpc.xdaichain.com",
			accounts,
			chainId: 100,
			live: true,
			saveDeployments: true
		},
		bsc: {
			url: "https://bsc-dataseed.binance.org",
			accounts,
			chainId: 56,
			live: true,
			saveDeployments: true
		},
		"bsc-testnet": {
			url: "https://data-seed-prebsc-2-s3.binance.org:8545",
			accounts,
			chainId: 97,
			live: true,
			saveDeployments: true,
			tags: ["staging"],
			gasMultiplier: 2
		},
		heco: {
			url: "https://http-mainnet.hecochain.com",
			accounts,
			chainId: 128,
			live: true,
			saveDeployments: true
		},
		"heco-testnet": {
			url: "https://http-testnet.hecochain.com",
			accounts,
			chainId: 256,
			live: true,
			saveDeployments: true,
			tags: ["staging"],
			gasMultiplier: 2
		},
		avalanche: {
			url: "https://api.avax.network/ext/bc/C/rpc",
			accounts,
			chainId: 43114,
			live: true,
			saveDeployments: true,
			gasPrice: 470000000000
		},
		fuji: {
			url: "https://api.avax-test.network/ext/bc/C/rpc",
			accounts,
			chainId: 43113,
			live: true,
			saveDeployments: true,
			tags: ["staging"],
			gasMultiplier: 2
		},
		harmony: {
			url: "https://api.s0.t.hmny.io",
			accounts,
			chainId: 1666600000,
			live: true,
			saveDeployments: true
		},
		"harmony-testnet": {
			url: "https://api.s0.b.hmny.io",
			accounts,
			chainId: 1666700000,
			live: true,
			saveDeployments: true,
			tags: ["staging"],
			gasMultiplier: 2
		},
		okex: {
			url: "https://exchainrpc.okex.org",
			accounts,
			chainId: 66,
			live: true,
			saveDeployments: true
		},
		"okex-testnet": {
			url: "https://exchaintestrpc.okex.org",
			accounts,
			chainId: 65,
			live: true,
			saveDeployments: true,
			tags: ["staging"],
			gasMultiplier: 2
		},
		arbitrum: {
			url: "https://arb1.arbitrum.io/rpc",
			accounts,
			chainId: 42161,
			live: true,
			saveDeployments: true,
			blockGasLimit: 700000
		},
		"arbitrum-testnet": {
			url: "https://kovan3.arbitrum.io/rpc",
			accounts,
			chainId: 79377087078960,
			live: true,
			saveDeployments: true,
			tags: ["staging"],
			gasMultiplier: 2
		},
		celo: {
			url: "https://forno.celo.org",
			accounts,
			chainId: 42220,
			live: true,
			saveDeployments: true
		},
		palm: {
			url: "https://palm-mainnet.infura.io/v3/da5fbfafcca14b109e2665290681e267",
			accounts,
			chainId: 11297108109,
			live: true,
			saveDeployments: true
		},
		"palm-testnet": {
			url: "https://palm-testnet.infura.io/v3/da5fbfafcca14b109e2665290681e267",
			accounts,
			chainId: 11297108099,
			live: true,
			saveDeployments: true,
			tags: ["staging"],
			gasMultiplier: 2
		},
		moonriver: {
			url: "https://rpc.moonriver.moonbeam.network",
			accounts,
			chainId: 1285,
			live: true,
			saveDeployments: true
		},
		fuse: {
			url: "https://rpc.fuse.io",
			accounts,
			chainId: 122,
			live: true,
			saveDeployments: true
		},
		clover: {
			url: "https://rpc-ivy.clover.finance",
			accounts,
			chainId: 1024,
			live: true,
			saveDeployments: true
		}
	},
	namedAccounts: {
		deployer: {
			default: 0
		},
		dev: {
			// Default to 1
			default: 1
			// dev address mainnet
			// 1: "",
		}
	},
	solidity: {
		compilers: [
			{
				version: "0.8.9",
				settings: {
					optimizer: {
						enabled: true,
						runs: 999
					}
				}
			}
		]
	},
	paths: {
		artifacts: "artifacts",
		cache: "cache",
		deploy: "deploy",
		deployments: "deployments",
		imports: "imports",
		sources: "contracts",
		tests: "tests"
	},
	mocha: {
		require: ["hardhat/register"],
		timeout: 20000
	},
	abiExporter: {
		path: "./abi",
		clear: false,
		flat: true
		// only: [],
		// except: []
	},
	etherscan: {
		apiKey: process.env.ETHERSCAN_API_KEY as string
	},
	gasReporter: {
		coinmarketcap: process.env.COINMARKETCAP_API_KEY,
		currency: "USD",
		enabled: process.env.REPORT_GAS === "true",
		excludeContracts: ["contracts/mocks/", "contracts/libraries/"]
	},
	preprocess: {
		eachLine: removeConsoleLog(
			(bre: {network: {name: string}}) =>
				bre.network.name !== "hardhat" && bre.network.name !== "localhost"
		)
	},
	spdxLicenseIdentifier: {
		overwrite: false,
		runOnCompile: true
	},
	tenderly: {
		project: process.env.TENDERLY_PROJECTNAME as string,
		username: process.env.TENDERLY_USERNAME as string
	},
	typechain: {
		outDir: "typechain-types",
		target: "ethers-v5"
	},
	watcher: {
		compile: {
			tasks: ["compile"],
			files: ["./contracts"],
			verbose: true
		}
	}
};

export default config;
