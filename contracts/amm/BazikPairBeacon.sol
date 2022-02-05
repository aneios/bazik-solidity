// SPDX-License-Identifier: MIT

pragma solidity >=0.8.9;

import "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

contract BazikPairBeacon is UpgradeableBeacon {
	constructor(address implementation_) UpgradeableBeacon(implementation_) {}

	function implementation() public view override returns (address) {
		return super.implementation();
	}

	function upgradeTo(address newImplementation_) public override onlyOwner {
		super.upgradeTo(newImplementation_);
		emit Upgraded(newImplementation_);
	}
}
