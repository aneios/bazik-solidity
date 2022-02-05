// SPDX-License-Identifier: MIT

pragma solidity >=0.8.9;

import "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import "@openzeppelin/contracts/proxy/beacon/IBeacon.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "../interfaces/IBazikPairFactory.sol";
import "../interfaces/IBazikRewarder.sol";
import "../interfaces/IBazikSwapPair.sol";

contract BazikPairFactory is AccessControlEnumerableUpgradeable, PausableUpgradeable, UUPSUpgradeable, IBazikPairFactory {
	using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;
	using AddressUpgradeable for address;

	bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
	bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

	address internal immutable _rewarderAddress;
	address internal immutable _bazikTokenAddress;
	address internal immutable _beaconAddress;

	uint256 internal _feePerMillion;
	IBeacon internal _beacon;
	EnumerableSetUpgradeable.AddressSet internal _tradedTokens;
	mapping(address => address) internal _tradingPair;

	constructor(address beaconAddress_, address rewarderAddress_) initializer {
		_rewarderAddress = rewarderAddress_;
		_bazikTokenAddress = IBazikRewarder(rewarderAddress_).bazikTokenAddress();
		_beaconAddress = beaconAddress_;
		_beacon = IBeacon(beaconAddress_);
	}

	function initialize() external initializer {
		__Pausable_init();

		_grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
		_grantRole(PAUSER_ROLE, msg.sender);
		_grantRole(UPGRADER_ROLE, msg.sender);

		_beacon = IBeacon(_beaconAddress);
	}

	function pause() external onlyRole(PAUSER_ROLE) {
		_pause();
	}

	function unpause() external onlyRole(PAUSER_ROLE) {
		_unpause();
	}

	function beaconAddress() external view returns (address) {
		return _beaconAddress;
	}

	function numberOfPairs() external view returns (uint256) {
		return _tradedTokens.length();
	}

	function feeRate() external view returns (uint256) {
		return _feePerMillion / 1000000;
	}

	function setFeePerMillion(uint256 feePerMillion_) external onlyRole(DEFAULT_ADMIN_ROLE) {
		_feePerMillion = feePerMillion_;
	}

	function getPairFor(address otherTokenAddress_) external returns (address) {
		if (_tradedTokens.add(otherTokenAddress_)) {
			require(otherTokenAddress_ != address(0), "BazikPairFactory: ZERO_ADDRESS");
			require(otherTokenAddress_ != _rewarderAddress, "BazikPairFactory: REWARDER_ADDRESS");
			require(otherTokenAddress_ != _bazikTokenAddress, "BazikPairFactory: IDENTICAL_ADDRESSES");
			require(otherTokenAddress_.isContract(), "BazikPairFactory: ADDRESS_NOT_VALID_CONTRACT");
			address pairAddress_ = address(
				new BeaconProxy(
					_beaconAddress,
					abi.encodeWithSelector(
						IBazikSwapPair(_beacon.implementation()).initialize.selector,
						_rewarderAddress,
						otherTokenAddress_
					)
				)
			);
			_tradingPair[otherTokenAddress_] = pairAddress_;
			emit PairCreated(_bazikTokenAddress, otherTokenAddress_, pairAddress_);
			return pairAddress_;
		}
		return _tradingPair[otherTokenAddress_];
	}

	function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {
		_beacon = IBeacon(IBazikPairFactory(newImplementation).beaconAddress());
	}
}
