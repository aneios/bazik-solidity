// SPDX-License-Identifier: MIT

pragma solidity >=0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "../interfaces/IBazikRewarder.sol";

/// @notice The (older) MasterChef contract gives out a constant number of _bazikToken tokens per block.
/// It is the only address with minting rights for _bazikToken.
/// The idea for this MasterChef V2 (MCV2) contract is therefore to be the owner of a dummy token
/// that is deposited into the MasterChef V1 (MCV1) contract.
/// The allocation point for this farm on MCV1 is the total allocation point for all pools that receive double incentives.
contract BazikRewarder is AccessControlEnumerableUpgradeable, PausableUpgradeable, UUPSUpgradeable, IBazikRewarder {
	using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;
	using SafeERC20 for IERC20;

	bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
	bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

	uint256 internal constant _ACC_BAZIK_PRECISION = 1e18;
	address internal immutable _bazikTokenAddress;

	uint256 internal _alreadyReleasedBazik;
	IERC20 internal _bazikToken;
	EnumerableSetUpgradeable.AddressSet internal _activeFarms;
	EnumerableSetUpgradeable.AddressSet internal _allFarms;
	mapping(address => uint256) internal _accBazikPerShare;
	mapping(address => mapping(address => FarmerInfo)) internal _farmerInfo;

	/// @custom:oz-upgrades-unsafe-allow constructor, state-variable-immutable
	constructor(address bazikTokenAddress_) initializer {
		_bazikTokenAddress = bazikTokenAddress_;
	}

	function initialize() public initializer {
		__Pausable_init();

		_grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
		_grantRole(PAUSER_ROLE, msg.sender);
		_grantRole(UPGRADER_ROLE, msg.sender);

		_bazikToken = IERC20(_bazikTokenAddress);
	}

	function pause() public onlyRole(PAUSER_ROLE) {
		_pause();
	}

	function unpause() public onlyRole(PAUSER_ROLE) {
		_unpause();
	}

	function bazikTokenAddress() external view returns (address) {
		return address(_bazikToken);
	}

	function numberOfActiveFarms() external view returns (uint256) {
		return _activeFarms.length();
	}

	function totalnumberOfFarms() external view returns (uint256) {
		return _allFarms.length();
	}

	function farmerInfo(address farmer_, address farmAddress_) external view returns (uint256, uint256) {
		return (_farmerInfo[farmAddress_][farmer_].deposited, _farmerInfo[farmAddress_][farmer_].rewardDebt);
	}

	function pendingBazik(address farmer_, address farmAddress_) external view returns (uint256) {
		FarmerInfo storage farmerInfo_ = _farmerInfo[farmAddress_][farmer_];
		uint256 accBazikPerShare_ = _accBazikPerShare[farmAddress_];
		if (_activeFarms.contains(farmAddress_)) {
			uint256 pairTokenSupply_ = IERC20(farmAddress_).balanceOf(address(this));
			if (pairTokenSupply_ > 0) {
				uint256 accumulatedBazik_ = (_bazikToken.balanceOf(address(this)) - _alreadyReleasedBazik) / _activeFarms.length();
				unchecked {
					accBazikPerShare_ += (accumulatedBazik_ * _ACC_BAZIK_PRECISION) / pairTokenSupply_;
				}
			}
		}
		return (farmerInfo_.deposited * accBazikPerShare_) / _ACC_BAZIK_PRECISION - farmerInfo_.rewardDebt;
	}

	function activateFarm(address farmAddress_) external onlyRole(DEFAULT_ADMIN_ROLE) whenNotPaused {
		_updateActiveFarms();
		_allFarms.add(farmAddress_);
		_activeFarms.add(farmAddress_);
		emit ActivateFarm(farmAddress_);
	}

	function deactivateFarm(address farmAddress_) external onlyRole(DEFAULT_ADMIN_ROLE) whenNotPaused {
		_updateActiveFarms();
		_activeFarms.remove(farmAddress_);
		emit DeactivateFarm(farmAddress_);
	}

	function updateActiveFarm(address farmAddress_) external whenNotPaused {
		require(_activeFarms.contains(farmAddress_), "BazikRewarder: INACTIVE_FARM");
		_updateFarm(farmAddress_);
		emit UpdateFarm(farmAddress_);
	}

	function deposit(address farmAddress_, uint256 amount_) external whenNotPaused {
		require(_activeFarms.contains(farmAddress_), "BazikRewarder: INACTIVE_FARM");

		// Variables
		FarmerInfo storage farmerInfo_ = _farmerInfo[farmAddress_][_msgSender()];
		uint256 accBazikPerShare_ = _updateFarm(farmAddress_);

		// Effects
		farmerInfo_.deposited += amount_;
		farmerInfo_.rewardDebt += (amount_ * accBazikPerShare_) / _ACC_BAZIK_PRECISION;
		IERC20(farmAddress_).safeTransferFrom(_msgSender(), address(this), amount_);

		emit Deposit(_msgSender(), farmAddress_, amount_);
	}

	function harvest(address farmAddress_) external whenNotPaused {
		// Variables
		FarmerInfo storage farmerInfo_ = _farmerInfo[farmAddress_][_msgSender()];
		uint256 accBazikPerShare_ = _activeFarms.contains(farmAddress_)
			? _updateFarm(farmAddress_)
			: _accBazikPerShare[farmAddress_];
		uint256 pendingBazik_ = (farmerInfo_.deposited * accBazikPerShare_) / _ACC_BAZIK_PRECISION - farmerInfo_.rewardDebt;

		// Effects
		farmerInfo_.rewardDebt += pendingBazik_;
		_bazikToken.safeTransferFrom(address(this), _msgSender(), pendingBazik_);

		emit Harvest(_msgSender(), farmAddress_, pendingBazik_);
	}

	function harvestAndWithdraw(address farmAddress_, uint256 amount_) external whenNotPaused {
		// Variables
		FarmerInfo storage farmerInfo_ = _farmerInfo[farmAddress_][_msgSender()];
		uint256 accBazikPerShare_ = _activeFarms.contains(farmAddress_)
			? _updateFarm(farmAddress_)
			: _accBazikPerShare[farmAddress_];
		uint256 pendingBazik_ = (farmerInfo_.deposited * accBazikPerShare_) / _ACC_BAZIK_PRECISION - farmerInfo_.rewardDebt;

		// Effects
		farmerInfo_.deposited -= amount_;
		farmerInfo_.rewardDebt = (farmerInfo_.deposited * accBazikPerShare_) / _ACC_BAZIK_PRECISION;

		_bazikToken.safeTransferFrom(address(this), _msgSender(), pendingBazik_);
		IERC20(farmAddress_).safeTransferFrom(address(this), _msgSender(), amount_);

		emit Harvest(_msgSender(), farmAddress_, pendingBazik_);
		emit Withdraw(_msgSender(), farmAddress_, amount_);
	}

	function emergencyWithdraw(address farmAddress_) external {
		FarmerInfo storage farmerInfo_ = _farmerInfo[farmAddress_][_msgSender()];
		uint256 deposited_ = farmerInfo_.deposited;
		farmerInfo_.deposited = 0;
		farmerInfo_.rewardDebt = 0;

		IERC20(farmAddress_).safeTransferFrom(address(this), _msgSender(), deposited_);

		emit EmergencyWithdraw(_msgSender(), farmAddress_, deposited_);
	}

	function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) {
		_bazikToken = IERC20(IBazikRewarder(newImplementation).bazikTokenAddress());
	}

	function _updateFarm(address farmAddress_) internal returns (uint256) {
		uint256 pairTokenSupply_ = IERC20(farmAddress_).balanceOf(address(this));
		if (pairTokenSupply_ > 0) {
			uint256 accumulatedBazik_ = (_bazikToken.balanceOf(address(this)) - _alreadyReleasedBazik) / _activeFarms.length();
			unchecked {
				_accBazikPerShare[farmAddress_] += (accumulatedBazik_ * _ACC_BAZIK_PRECISION) / pairTokenSupply_;
			}
			_alreadyReleasedBazik += accumulatedBazik_;
		}
		return _accBazikPerShare[farmAddress_];
	}

	function _updateActiveFarms() internal {
		for (uint256 i; i < _activeFarms.length(); i++) {
			_updateFarm(_activeFarms.at(i));
		}
	}
}
