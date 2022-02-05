// SPDX-License-Identifier: MIT

pragma solidity >=0.8.9;

interface IBazikSwapCaller {
	function bazikSwapCall(
		address swaper_,
		uint256 amountBazik_,
		uint256 amountOther_,
		bytes calldata data_
	) external;
}
