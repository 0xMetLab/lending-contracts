// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IWETH} from "../../interfaces/IWETH.sol";

/// @title Dust Refunder Contract
/// @dev Refunds dust tokens remaining from zapping.
contract DustRefunder {
	using SafeERC20 for IERC20;

	/**
	 * @notice Refunds Met and WETH.
	 * @param _met MET address
	 * @param _weth WETH address
	 * @param _refundAddress Address for refund
	 */
	function _refundDust(address _met, address _weth, address _refundAddress) internal {
		IERC20 met = IERC20(_met);
		IWETH weth = IWETH(_weth);

		uint256 dustWETH = weth.balanceOf(address(this));
		if (dustWETH > 0) {
			weth.transfer(_refundAddress, dustWETH);
		}
		uint256 dustMet = met.balanceOf(address(this));
		if (dustMet > 0) {
			met.safeTransfer(_refundAddress, dustMet);
		}
	}
}