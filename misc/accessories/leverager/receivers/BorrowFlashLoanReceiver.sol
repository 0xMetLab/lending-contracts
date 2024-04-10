// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

import {SafeMath} from '@openzeppelin/contracts/utils/math/SafeMath.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {ILendingPoolAddressesProvider} from '../../../../interfaces/ILendingPoolAddressesProvider.sol';
import {IBorrowFlashLoanReceiver} from '../interfaces/IBorrowFlashLoanReceiver.sol';
import {ICreditDelegationToken} from '../../../../interfaces/ICreditDelegationToken.sol';
import {BaseFlashLoanReceiver} from './BaseFlashLoanReceiver.sol';
import {Calculator} from '../libraries/Calculator.sol';

contract BorrowFlashLoanReceiver is IBorrowFlashLoanReceiver, BaseFlashLoanReceiver {
  using SafeERC20 for IERC20;
  using SafeMath for uint256;

  error ExceedsMaxBorrowAmount();

  struct ExecuteOperationLocalVars {
    address collateralAsset;
    uint256 flashLoanAmount;
    uint256 depositAmount;
    address borrowAsset;
    uint256 borrowAmount;
    uint256 maxBorrowAmount;
    uint256 premiumAmount;
    uint256 collateralPriceInUsd;
    uint256 borrowPriceInUsd;
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
    vars.collateralAsset = assets[0];
    vars.flashLoanAmount = amounts[0];
    vars.premiumAmount = premiums[0];
    (vars.depositAmount, vars.borrowAsset, vars.borrowAmount, vars.onBehalfOf, vars.to, vars.data) = abi.decode(
      params,
      (uint256, address, uint256, address, address, bytes)
    );
    (vars.maxBorrowAmount, , ) = Calculator.calculateBorrow(
      vars.collateralAsset,
      vars.depositAmount,
      vars.borrowAsset,
      DATA_PROVIDER,
      PRICE_ORACLE
    );
    if (vars.borrowAmount > vars.maxBorrowAmount) revert ExceedsMaxBorrowAmount();
    IERC20(vars.collateralAsset).forceApprove(address(LENDING_POOL), type(uint256).max);
    LENDING_POOL.deposit(vars.collateralAsset, vars.depositAmount, vars.onBehalfOf, 0);
    LENDING_POOL.borrow(vars.borrowAsset, vars.borrowAmount, 2, 0, vars.onBehalfOf);
    IERC20(vars.borrowAsset).forceApprove(vars.to, vars.borrowAmount);
    (bool success, bytes memory result) = payable(vars.to).call(vars.data);
    if (!success) revert SwapFailed();
    uint256 swappedAmount = abi.decode(result, (uint256));
    uint256 repaymentAmount = vars.flashLoanAmount + vars.premiumAmount;
    IERC20(vars.collateralAsset).approve(address(LENDING_POOL), repaymentAmount);
    uint256 leftover = swappedAmount - repaymentAmount;
    if (leftover > 0) {
      IERC20(vars.collateralAsset).safeTransfer(vars.onBehalfOf, leftover);
    }
    return true;
  }
}
