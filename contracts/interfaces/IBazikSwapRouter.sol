// SPDX-License-Identifier: MIT

pragma solidity >=0.8.9;

import "@openzeppelin/contracts-upgradeable/access/IAccessControlEnumerableUpgradeable.sol";

interface IBazikSwapRouter is IAccessControlEnumerableUpgradeable {
	function bazikTokenAddress() external view returns (address);

	function pairFactoryAddress() external view returns (address);

	function nativeWrapperAddress() external view returns (address);

	function addLiquidity(
		address otherTokenAddress,
		uint256 amountBazikToAdd,
		uint256 amountOtherToAdd,
		address provider,
		uint256 deadline
	) external returns (uint256);

	function removeLiquidity(
		address otherTokenAddress,
		uint256 amountLPToRemove,
		address redeemer,
		uint256 deadline
	) external returns (uint256, uint256);

	function removeLiquidityWithPermit(
		address otherTokenAddress,
		uint256 amountLPToRemove,
		address redeemer,
		uint256 deadline,
		bool approveMax,
		uint8 v,
		bytes32 r,
		bytes32 s
	) external returns (uint256, uint256);

	function swapExactTokensForTokens(
		uint256 amountIn,
		uint256 amountOutMin,
		address[] calldata path,
		address to,
		uint256 deadline
	) external returns (uint256[] memory amounts);

	function swapTokensForExactTokens(
		uint256 amountOut,
		uint256 amountInMax,
		address[] calldata path,
		address to,
		uint256 deadline
	) external returns (uint256[] memory amounts);

	function swapExactTokensForTokensSupportingFeeOnTransferTokens(
		uint256 amountIn,
		uint256 amountOutMin,
		address[] calldata path,
		address to,
		uint256 deadline
	) external;

	function quote(
		uint256 amountA,
		uint256 reserveA,
		uint256 reserveB
	) external pure returns (uint256 amountB);

	function getAmountOut(
		uint256 amountIn,
		uint256 reserveIn,
		uint256 reserveOut
	) external pure returns (uint256 amountOut);

	function getAmountIn(
		uint256 amountOut,
		uint256 reserveIn,
		uint256 reserveOut
	) external pure returns (uint256 amountIn);

	function getAmountsOut(uint256 amountIn, address[] calldata path) external view returns (uint256[] memory amounts);

	function getAmountsIn(uint256 amountOut, address[] calldata path) external view returns (uint256[] memory amounts);
}
