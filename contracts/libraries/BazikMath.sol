// SPDX-License-Identifier: MIT

pragma solidity >=0.8.9;

// a library for performing various math operations

library BazikMath {
	uint256 constant Q128 = 2**128;

	// encode a uint128 as a UQ128x128
	function encode128(uint128 y) internal pure returns (uint256) {
		unchecked {
			return uint256(y) * Q128;
		}
	}

	// divide a UQ128x128 by a uint128, returning a UQ128x128
	function uqdiv(uint256 x, uint128 y) internal pure returns (uint256) {
		unchecked {
			return x / uint256(y);
		}
	}

	/**
	 * @dev Compute the largest integer smaller than or equal to the square root of 'n'
	 */
	function floorSqrt(uint256 n) internal pure returns (uint256) {
		unchecked {
			if (n > 0) {
				uint256 x = n / 2 + 1;
				uint256 y = (x + n / x) / 2;
				while (x > y) {
					x = y;
					y = (x + n / x) / 2;
				}
				return x;
			}
			return 0;
		}
	}

	/**
	 * @dev Compute the smallest integer larger than or equal to the square root of 'n'
	 */
	function ceilSqrt(uint256 n) internal pure returns (uint256) {
		unchecked {
			uint256 x = floorSqrt(n);
			return x**2 == n ? x : x + 1;
		}
	}
}
