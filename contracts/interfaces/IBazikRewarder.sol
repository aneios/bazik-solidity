// SPDX-License-Identifier: MIT
pragma solidity >=0.8.9;

import "@openzeppelin/contracts-upgradeable/access/IAccessControlEnumerableUpgradeable.sol";

interface IBazikRewarder is IAccessControlEnumerableUpgradeable {
	event ActivateFarm(address indexed farmAddress_);
	event DeactivateFarm(address indexed farmAddress_);
	event UpdateFarm(address indexed farmAddress_);
	event Deposit(address indexed farmer_, address indexed farmAddress_, uint256 amount_);
	event Harvest(address indexed farmer_, address indexed farmAddress, uint256 pendingBazik_);
	event Withdraw(address indexed farmer_, address indexed farmAddress_, uint256 amount_);
	event EmergencyWithdraw(address indexed farmer_, address indexed farmAddress_, uint256 deposited_);

	struct FarmerInfo {
		uint256 deposited;
		uint256 rewardDebt;
	}

	function bazikTokenAddress() external view returns (address);

	function numberOfActiveFarms() external view returns (uint256);

	function totalnumberOfFarms() external view returns (uint256);

	function farmerInfo(address farmer_, address farmAddress_) external view returns (uint256, uint256);

	function pendingBazik(address farmer_, address farmAddress_) external view returns (uint256);

	function activateFarm(address farmAddress_) external;

	function deactivateFarm(address farmAddress_) external;

	function updateActiveFarm(address farmAddress_) external;

	function deposit(address farmAddress_, uint256 amount_) external;

	function harvest(address farmAddress_) external;

	function harvestAndWithdraw(address farmAddress_, uint256 amount_) external;

	function emergencyWithdraw(address farmAddress_) external;
}
