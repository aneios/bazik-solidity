// SPDX-License-Identifier: MIT

pragma solidity >=0.8.9;

import "@openzeppelin/contracts-upgradeable/access/IAccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/draft-IERC20PermitUpgradeable.sol";

interface IBazikSwapPair is IAccessControlEnumerableUpgradeable, IERC20MetadataUpgradeable, IERC20PermitUpgradeable {
	event Provide(address indexed provider_, uint256 amountBazik_, uint256 amountOther_);
	event Redeem(address indexed redeemer_, uint256 amountBazik_, uint256 amountOther_);
	event Swap(
		address indexed swaper_,
		uint256 amountBazikIn_,
		uint256 amountOtherIn_,
		uint256 amountBazikOut_,
		uint256 amountOtherOut_
	);
	event Update(uint256 reserveBazik_, uint256 reserveOther_);

	function initialize(address rewarderAddress_, address otherTokenAddress_) external;

	function bazikTokenAddress() external view returns (address);

	function otherTokenAddress() external view returns (address);

	function rewarderAddress() external view returns (address);

	function reserveBazik() external view returns (uint128);

	function reserveOther() external view returns (uint128);

	function swappingFee() external view returns (uint256);

	function estimateBazikIn(uint256 amountOtherOut_) external view returns (uint256);

	function estimateBazikOut(uint256 amountOtherIn_) external view returns (uint256);

	function estimateOtherIn(uint256 amountBazikOut_) external view returns (uint256);

	function estimateOtherOut(uint256 amountOtherIn_) external view returns (uint256);

	function skim() external;

	function sync() external;

	function setFee(uint256 feePerMillion_) external;

	function swap(
		address swaper_,
		uint256 amountBazikOut_,
		uint256 amountOtherOut_,
		bytes calldata data_
	) external;

	function provide(address provider_) external returns (uint256);

	function redeem(address redeemer_) external returns (uint256, uint256);
}
