// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

import {SafeMath} from '@openzeppelin/contracts/utils/math/SafeMath.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {ILendingPoolAddressesProvider} from '../../../../interfaces/ILendingPoolAddressesProvider.sol';
import {IRepayFlashLoanReceiver} from '../interfaces/IRepayFlashLoanReceiver.sol';
import {BaseFlashLoanReceiver} from './BaseFlashLoanReceiver.sol';

contract RepayFlashLoanReceiver is IRepayFlashLoanReceiver, BaseFlashLoanReceiver {
  using SafeERC20 for IERC20;
  using SafeMath for uint256;

  error InsufficientSwapAmount(uint256 needed, uint256 got);

  struct ExecuteOperationLocalVars {
    address flashLoanAsset;
    uint256 flashLoanAmount;
    uint256 premiumAmount;
    address swapAsset;
    uint256 swapAmount;
    address onBehalfOf;
    address to;
    bytes data;
  }

  constructor(ILendingPoolAddressesProvider provider) BaseFlashLoanReceiver(provider) {}

  function requestFlashLoan(
    address onBehalfOf,
    address borrowAsset,
    uint256 borrowAmount,
    bytes calldata params
  ) external {
    address[] memory assets = new address[](1);
    assets[0] = borrowAsset;
    uint256[] memory amounts = new uint256[](1);
    amounts[0] = borrowAmount;
    uint256[] memory modes = new uint256[](1);
    modes[0] = 0;
    LENDING_POOL.flashLoan(address(this), assets, amounts, modes, onBehalfOf, params, 0);
  }

  function executeOperation(
    address[] calldata assets,
    uint256[] calldata amounts,
    uint256[] calldata premiums,
    address,
    bytes calldata params
  ) external returns (bool) {
    if (assets.length != 1) {
      revert InconsistentParams();
    }
    if (amounts.length != 1) {
      revert InconsistentParams();
    }
    if (premiums.length != 1) {
      revert InconsistentParams();
    }
    ExecuteOperationLocalVars memory vars;
    vars.flashLoanAsset = assets[0];
    vars.flashLoanAmount = amounts[0];
    vars.premiumAmount = premiums[0];
    (vars.swapAsset, vars.swapAmount, vars.onBehalfOf, vars.to, vars.data) = abi.decode(
      params,
      (address, uint256, address, address, bytes)
    );
    IERC20(vars.flashLoanAsset).forceApprove(address(LENDING_POOL), vars.flashLoanAmount);
    LENDING_POOL.repay(vars.flashLoanAsset, vars.flashLoanAmount, 2, vars.onBehalfOf);
    LENDING_POOL.withdraw(vars.swapAsset, vars.swapAmount, address(this), vars.onBehalfOf);
    IERC20(vars.swapAsset).forceApprove(vars.to, vars.swapAmount);
    (bool success, bytes memory result) = payable(vars.to).call(vars.data);
    if (!success) revert SwapFailed();
    uint256 swappedAmount = abi.decode(result, (uint256));
    uint256 owingAmount = vars.flashLoanAmount + vars.premiumAmount;
    IERC20(vars.flashLoanAsset).approve(address(LENDING_POOL), owingAmount);
    uint256 leftover = swappedAmount - owingAmount;
    if (leftover > 0) {
      IERC20(vars.flashLoanAsset).safeTransfer(vars.onBehalfOf, leftover);
    }
    return true;
  }
}
