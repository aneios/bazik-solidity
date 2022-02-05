// SPDX-License-Identifier: MIT

pragma solidity >=0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "../interfaces/IBazikPairFactory.sol";
import "../interfaces/IBazikSwapRouter.sol";
import "../interfaces/IWNative.sol";
import "../libraries/AMM.sol";

contract BazikSwapRouter is AccessControlEnumerableUpgradeable, PausableUpgradeable, UUPSUpgradeable, IBazikSwapRouter {
	using SafeERC20 for IERC20;

	bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
	bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

	address private _bazikTokenAddress;
	address private _pairFactoryAddress;
	address private _nativeWrapperAddress;
	IERC20 private _bazikToken;
	IBazikPairFactory private _pairFactory;
	IWNative private _nativeWrapper;

	/// @custom:oz-upgrades-unsafe-allow constructor
	constructor(
		address bazikTokenAddress_,
		address pairFactoryAddress_,
		address nativeWrapperAddress_
	) initializer {
		_bazikTokenAddress = bazikTokenAddress_;
		_pairFactoryAddress = pairFactoryAddress_;
		_nativeWrapperAddress = nativeWrapperAddress_;

		_bazikToken = IERC20(bazikTokenAddress_);
		_pairFactory = IBazikPairFactory(pairFactoryAddress_);
		_nativeWrapper = IWNative(nativeWrapperAddress_);
	}

	function initialize() public initializer {
		__Pausable_init();
		__AccessControl_init();
		__UUPSUpgradeable_init();

		_grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
		_grantRole(PAUSER_ROLE, msg.sender);
		_grantRole(UPGRADER_ROLE, msg.sender);
	}

	function bazikTokenAddress() external view virtual override returns (address) {
		return _bazikTokenAddress;
	}

	function pairFactoryAddress() external view virtual override returns (address) {
		return _pairFactoryAddress;
	}

	function nativeWrapperAddress() external view virtual override returns (address) {
		return _nativeWrapperAddress;
	}

	modifier ensure(uint256 deadline_) {
		require(deadline_ >= block.timestamp, "BazikSwapRouter: EXPIRED");
		_;
	}

	receive() external payable {
		assert(_msgSender() == _nativeWrapperAddress); // only accept ETH via fallback from the WETH contract
	}

	function addLiquidity(
		address provider_,
		address otherTokenAddress_,
		uint256 amountBazikToAdd_,
		uint256 amountOtherToAdd_,
		uint256 deadline_
	) external virtual ensure(deadline_) returns (uint256) {
		address pairAddress_ = _pairFactory.getPairFor(otherTokenAddress_);
		_bazikToken.safeTransferFrom(_msgSender(), pairAddress_, amountBazikToAdd_);
		IERC20(otherTokenAddress_).safeTransferFrom(_msgSender(), pairAddress_, amountOtherToAdd_);
		return IBazikSwapPair(pairAddress_).provide(provider_);
	}

	// **** REMOVE LIQUIDITY ****
	function removeLiquidity(
		address redeemer_,
		address otherTokenAddress_,
		uint256 amountLPToRemove_,
		uint256 deadline_
	) public virtual ensure(deadline_) returns (uint256, uint256) {
		address pairAddress_ = _pairFactory.getPairFor(otherTokenAddress_);
		IERC20(pairAddress_).safeTransferFrom(_msgSender(), pairAddress_, amountLPToRemove_); // send liquidity to pair
		return IBazikSwapPair(pairAddress_).redeem(redeemer_);
	}

	function removeLiquidityWithPermit(
		address redeemer_,
		address otherTokenAddress_,
		uint256 amountLPToRemove_,
		uint256 deadline_,
		bool approveMax_,
		uint8 v_,
		bytes32 r_,
		bytes32 s_
	) external returns (uint256, uint256) {
		address pairAddress_ = _pairFactory.getPairFor(otherTokenAddress_);
		uint256 value_ = approveMax_ ? type(uint256).max : amountLPToRemove_;
		IBazikSwapPair(pairAddress_).permit(_msgSender(), address(this), value_, deadline_, v_, r_, s_);
		IERC20(pairAddress_).safeTransferFrom(_msgSender(), pairAddress_, amountLPToRemove_); // send liquidity to pair
		return IBazikSwapPair(pairAddress_).redeem(redeemer_);
	}

	// **** SWAP (supporting fee-on-transfer tokens) ****
	// requires the initial amount to have already been sent to the first pair
	function _swapSupportingFeeOnTransfer(address tokenInAddress_, address tokenOutAddress_) internal {
		if (tokenInAddress_ == _bazikTokenAddress) {
			address pairAddress_ = _pairFactory.getPairFor(tokenOutAddress_);
			IBazikSwapPair pair_ = IBazikSwapPair(pairAddress_);

			pair_.swap(
				_msgSender(),
				0,
				pair_.estimateOtherOut(_bazikToken.balanceOf(pairAddress_) - pair_.reserveBazik()),
				new bytes(0)
			);
		} else if (tokenOutAddress_ == _bazikTokenAddress) {
			address pairAddress_ = _pairFactory.getPairFor(tokenInAddress_);
			IBazikSwapPair pair_ = IBazikSwapPair(pairAddress_);

			pair_.swap(
				_msgSender(),
				pair_.estimateBazikOut(IERC20(tokenInAddress_).balanceOf(pairAddress_) - pair_.reserveOther()),
				0,
				new bytes(0)
			);
		} else {
			address pair1Address_ = _pairFactory.getPairFor(tokenInAddress_);
			address pair2Address_ = _pairFactory.getPairFor(tokenOutAddress_);
			IBazikSwapPair pair1_ = IBazikSwapPair(pair1Address_);

			pair1_.swap(
				pair2Address_,
				pair1_.estimateBazikOut(IERC20(tokenInAddress_).balanceOf(pair1Address_) - pair1_.reserveOther()),
				0,
				new bytes(0)
			);

			IBazikSwapPair pair2_ = IBazikSwapPair(pair2Address_);

			pair2_.swap(
				_msgSender(),
				0,
				pair2_.estimateOtherOut(_bazikToken.balanceOf(pair2Address_) - pair2_.reserveBazik()),
				new bytes(0)
			);
		}
	}

	function swapExactTokensForTokens(
		uint256 amountIn,
		uint256 amountOutMin,
		address[] calldata path,
		address to,
		uint256 deadline
	) external virtual override ensure(deadline) returns (uint256[] memory amounts) {
		amounts = UniswapV2Library.getAmountsOut(_pairFactoryAddress, amountIn, path);
		require(amounts[amounts.length - 1] >= amountOutMin, "UniswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT");
		SafeERC20.safeTransferFrom(
			path[0],
			_msgSender(),
			UniswapV2Library.pairFor(_pairFactoryAddress, path[0], path[1]),
			amounts[0]
		);
		_swap(amounts, path, to);
	}

	function swapTokensForExactTokens(
		uint256 amountOut,
		uint256 amountInMax,
		address[] calldata path,
		address to,
		uint256 deadline
	) external virtual override ensure(deadline) returns (uint256[] memory amounts) {
		amounts = UniswapV2Library.getAmountsIn(_pairFactoryAddress, amountOut, path);
		require(amounts[0] <= amountInMax, "UniswapV2Router: EXCESSIVE_INPUT_AMOUNT");
		SafeERC20.safeTransferFrom(
			path[0],
			_msgSender(),
			UniswapV2Library.pairFor(_pairFactoryAddress, path[0], path[1]),
			amounts[0]
		);
		_swap(amounts, path, to);
	}

	function swapExactTokensForTokensSupportingFeeOnTransferTokens(
		uint256 amountIn,
		uint256 amountOutMin,
		address[] calldata path,
		address to,
		uint256 deadline
	) external virtual override ensure(deadline) {
		SafeERC20.safeTransferFrom(
			path[0],
			_msgSender(),
			UniswapV2Library.pairFor(_pairFactoryAddress, path[0], path[1]),
			amountIn
		);
		uint256 balanceBefore = IERC20(path[path.length - 1]).balanceOf(to);
		_swapSupportingFeeOnTransferTokens(path, to);
		require(
			IERC20(path[path.length - 1]).balanceOf(to) - balanceBefore >= amountOutMin,
			"UniswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT"
		);
	}

	// **** LIBRARY FUNCTIONS ****
	function quote(
		uint256 amountA,
		uint256 reserveA,
		uint256 reserveB
	) public pure virtual override returns (uint256 amountB) {
		return UniswapV2Library.quote(amountA, reserveA, reserveB);
	}

	function getAmountOut(
		uint256 amountIn,
		uint256 reserveIn,
		uint256 reserveOut
	) public pure virtual override returns (uint256 amountOut) {
		return UniswapV2Library.getAmountOut(amountIn, reserveIn, reserveOut);
	}

	function getAmountIn(
		uint256 amountOut,
		uint256 reserveIn,
		uint256 reserveOut
	) public pure virtual override returns (uint256 amountIn) {
		return UniswapV2Library.getAmountIn(amountOut, reserveIn, reserveOut);
	}

	function getAmountsOut(uint256 amountIn, address[] memory path)
		public
		view
		virtual
		override
		returns (uint256[] memory amounts)
	{
		return UniswapV2Library.getAmountsOut(_pairFactoryAddress, amountIn, path);
	}

	function getAmountsIn(uint256 amountOut, address[] memory path)
		public
		view
		virtual
		override
		returns (uint256[] memory amounts)
	{
		return UniswapV2Library.getAmountsIn(_pairFactoryAddress, amountOut, path);
	}
}
