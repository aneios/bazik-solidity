// SPDX-License-Identifier: MIT

pragma solidity >=0.8.9;

import "@openzeppelin/contracts-upgradeable/access/IAccessControlEnumerableUpgradeable.sol";

interface IBazikPairFactory is IAccessControlEnumerableUpgradeable {
	event PairCreated(address indexed bazikTokenAddress_, address indexed otherTokenAddress_, address pairAddress_);

	function beaconAddress() external view returns (address);

	function numberOfPairs() external view returns (uint256);

	function feeRate() external view returns (uint256);

	function setFeePerMillion(uint256 feePerMillion_) external;

	function getPairFor(address otherTokenAddress_) external returns (address);
}
