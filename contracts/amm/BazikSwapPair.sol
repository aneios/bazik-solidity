// SPDX-License-Identifier: MIT

pragma solidity >=0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20VotesUpgradeable.sol";
import "../interfaces/IBazikRewarder.sol";
import "../interfaces/IBazikSwapCaller.sol";
import "../interfaces/IBazikSwapPair.sol";
import "../libraries/BazikMath.sol";

/// @custom:security-contact bazik.defi@protonmail.com
contract BazikSwapPair is AccessControlEnumerableUpgradeable, PausableUpgradeable, ERC20VotesUpgradeable, IBazikSwapPair {
	using SafeERC20 for IERC20;

	bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

	uint256 internal constant _PRECISION = 10**6;

	IBazikRewarder internal _rewarder;
	IERC20 internal _bazikToken;
	IERC20 internal _otherToken;
	uint128 internal _reserveBazik; // uses single storage slot
	uint128 internal _reserveOther; // uses single storage slot
	uint256 internal _swappingFee;

	/// @custom:oz-upgrades-unsafe-allow constructor
	constructor() initializer {}

	// called once by the factory at time of deployment
	function initialize(address rewarderAddress_, address otherTokenAddress_) external initializer {
		__Pausable_init();
		__ERC20_init("BazikSwap LP Token", "BZLP");
		__ERC20Permit_init("BazikSwap LP Token");

		_grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
		_grantRole(PAUSER_ROLE, msg.sender);

		_rewarder = IBazikRewarder(rewarderAddress_);
		_bazikToken = IERC20(_rewarder.bazikTokenAddress());
		_otherToken = IERC20(otherTokenAddress_);
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

	function otherTokenAddress() external view returns (address) {
		return address(_otherToken);
	}

	function rewarderAddress() external view returns (address) {
		return address(_rewarder);
	}

	function reserveBazik() external view returns (uint128) {
		return _reserveBazik;
	}

	function reserveOther() external view returns (uint128) {
		return _reserveOther;
	}

	function swappingFee() external view returns (uint256) {
		return _swappingFee;
	}

	// given an output amount of an asset and pair reserves, returns a required input amount of the other asset
	function estimateBazikIn(uint256 amountOtherOut_) external view returns (uint256) {
		uint256 numerator = _reserveBazik * amountOtherOut_ * _PRECISION;
		uint256 denominator = (_reserveOther - amountOtherOut_) * (_PRECISION - _swappingFee);
		return (numerator / denominator) + 1;
	}

	// given an input amount of an asset and pair reserves, returns the maximum output amount of the other asset
	function estimateBazikOut(uint256 amountOtherIn_) external view returns (uint256) {
		uint256 numerator = _reserveBazik * amountOtherIn_ * (_PRECISION - _swappingFee);
		uint256 denominator = _reserveOther * _PRECISION + amountOtherIn_ * (_PRECISION - _swappingFee);
		return (numerator / denominator);
	}

	function estimateOtherIn(uint256 amountBazikOut_) external view returns (uint256) {
		uint256 numerator = _reserveOther * amountBazikOut_ * _PRECISION;
		uint256 denominator = (_reserveBazik - amountBazikOut_) * (_PRECISION - _swappingFee);
		return (numerator / denominator) + 1;
	}

	// given an input amount of an asset and pair reserves, returns the maximum output amount of the other asset
	function estimateOtherOut(uint256 amountBazikIn_) external view returns (uint256) {
		uint256 numerator = _reserveOther * amountBazikIn_ * (_PRECISION - _swappingFee);
		uint256 denominator = _reserveBazik * _PRECISION + amountBazikIn_ * (_PRECISION - _swappingFee);
		return (numerator / denominator);
	}

	// force balances to match reserves
	function skim() external whenNotPaused {
		_bazikToken.safeTransferFrom(address(this), address(_rewarder), _bazikToken.balanceOf(address(this)) - _reserveBazik);
	}

	// force reserves to match balances
	function sync() external whenNotPaused {
		_update(_bazikToken.balanceOf(address(this)), _otherToken.balanceOf(address(this)));
	}

	function setFee(uint256 swappingFee_) external onlyRole(DEFAULT_ADMIN_ROLE) {
		_swappingFee = swappingFee_;
	}

	// this low-level function should be called from a contract which performs important safety checks
	function swap(
		address swaper_,
		uint256 amountBazik_,
		uint256 amountOther_,
		bytes calldata data_
	) external whenNotPaused {
		require(amountBazik_ > 0 || amountOther_ > 0, "BazikSwapPair: INSUFFICIENT_OUTPUT_AMOUNT");
		require(swaper_ != address(_bazikToken) && swaper_ != address(_otherToken), "BazikSwapPair: INVALID_SWAPER");

		uint256 _feeBazik = (amountBazik_ * _swappingFee) / _PRECISION;
		require(amountBazik_ + _feeBazik < _reserveBazik, "BazikSwapPair: INSUFFICIENT_BAZIK_LIQUIDITY_FOR_SWAP");
		uint256 _feeOther = (amountOther_ * _swappingFee) / _PRECISION;
		require(amountOther_ + _feeOther < _reserveOther, "BazikSwapPair: INSUFFICIENT_OTHER_LIQUIDITY_FOR_SWAP");

		if (amountBazik_ > 0) {
			_bazikToken.safeTransferFrom(address(this), swaper_, amountBazik_); // optimistically transfer tokens
			_bazikToken.safeTransferFrom(address(this), address(_rewarder), _feeBazik);
		}

		if (amountOther_ > 0) {
			_otherToken.safeTransferFrom(address(this), swaper_, amountOther_); // optimistically transfer tokens
		}

		if (data_.length > 0) IBazikSwapCaller(swaper_).bazikSwapCall(_msgSender(), amountBazik_, amountOther_, data_);

		uint256 balanceBazik_ = _bazikToken.balanceOf(address(this));
		uint256 balanceOther_ = _otherToken.balanceOf(address(this));
		require(
			balanceBazik_ * balanceOther_ >= uint256(_reserveBazik) * (uint256(_reserveOther) + _feeOther),
			"BazikSwapPair: INSUFFICIENT_INPUT_AMOUNT"
		);

		_update(balanceBazik_, balanceOther_);
		emit Swap(
			swaper_,
			balanceBazik_ - (_reserveBazik - amountBazik_ - _feeBazik),
			balanceOther_ - (_reserveOther - amountOther_),
			amountBazik_,
			amountOther_
		);
	}

	// this low-level function should be called from a contract which performs important safety checks
	function provide(address provider_) external whenNotPaused returns (uint256) {
		uint256 balanceBazik_ = _bazikToken.balanceOf(address(this));
		require(balanceBazik_ > _reserveBazik, "BazikSwapPair: INSUFFICIENT_BAZIK_LIQUIDITY_PROVIDED");
		uint256 balanceOther_ = _otherToken.balanceOf(address(this));
		require(balanceOther_ > _reserveOther, "BazikSwapPair: INSUFFICIENT_OTHER_LIQUIDITY_PROVIDED");
		unchecked {
			uint256 amountBazik_ = balanceBazik_ - _reserveBazik;
			uint256 amountOther_ = balanceOther_ - _reserveOther;
			uint256 liquidity_ = BazikMath.floorSqrt(amountBazik_ * amountOther_);
			require(liquidity_ > _PRECISION, "BazikSwapPair: INSUFFICIENT_TOTAL_LIQUIDITY_PROVIDED");

			if (totalSupply() == 0) {
				_mint(address(0), _PRECISION); // permanently lock the first MINIMUM_LIQUIDITY tokens
				liquidity_ = liquidity_ - _PRECISION;
			}
			_mint(provider_, liquidity_);

			_update(balanceBazik_, balanceOther_);
			emit Provide(provider_, amountBazik_, amountOther_);
			return liquidity_;
		}
	}

	// this low-level function should be called from a contract which performs important safety checks
	function redeem(address redeemer_) external whenNotPaused returns (uint256, uint256) {
		uint256 liquidity_ = balanceOf(address(this));
		require(liquidity_ > 0, "BazikSwapPair: INSUFFICIENT_LIQUIDITY_TO_REDEEM");
		uint256 totalSupply_ = totalSupply(); // gas savings
		uint256 amountBazik_ = (liquidity_ * _reserveBazik) / totalSupply_; // ensures pro-rata distribution
		uint256 amountOther_ = (liquidity_ * _reserveOther) / totalSupply_; // ensures pro-rata distribution

		_burn(address(this), liquidity_);
		_bazikToken.safeTransferFrom(address(this), redeemer_, amountBazik_);
		_otherToken.safeTransferFrom(address(this), redeemer_, amountOther_);

		_update(_bazikToken.balanceOf(address(this)), _otherToken.balanceOf(address(this)));
		emit Redeem(redeemer_, amountBazik_, amountOther_);
		return (amountBazik_, amountOther_);
	}

	function _beforeTokenTransfer(
		address from_,
		address to_,
		uint256 amount_
	) internal override whenNotPaused {
		super._beforeTokenTransfer(from_, to_, amount_);
	}

	function _update(uint256 reserveBazik_, uint256 reserveOther_) internal {
		require(reserveBazik_ <= type(uint128).max && reserveOther_ <= type(uint128).max, "BazikSwapPair: UPDATE_OVERFLOW");
		_reserveBazik = uint128(reserveBazik_);
		_reserveOther = uint128(reserveOther_);
		emit Update(reserveBazik_, reserveOther_);
	}
}
