import {HardhatRuntimeEnvironment} from "hardhat/types";

export default async function (hre: HardhatRuntimeEnvironment) {
	const {deployments, getNamedAccounts} = hre;

	const {deployer} = await getNamedAccounts();

	await deployments.deploy("BazikLPToken", {
		from: deployer,
		log: true,
		deterministicDeployment: false
	});
}

export const tags = ["BazikLPToken"];
export const dependencies = ["ERC20Token"];
