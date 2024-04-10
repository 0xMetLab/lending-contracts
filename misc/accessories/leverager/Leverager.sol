// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {Initializable} from '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
import {OwnableUpgradeable} from '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';
import {ILendingPool} from '../../../interfaces/ILendingPool.sol';
import {IAaveProtocolDataProvider} from '../../../interfaces/IAaveProtocolDataProvider.sol';
import {IBorrowFlashLoanReceiver} from './interfaces/IBorrowFlashLoanReceiver.sol';
import {IRepayFlashLoanReceiver} from './interfaces/IRepayFlashLoanReceiver.sol';
import {ICreditDelegationToken} from '../../../interfaces/ICreditDelegationToken.sol';
import {ILendingPoolAddressesProvider} from '../../../interfaces/ILendingPoolAddressesProvider.sol';

contract Leverager is Initializable, OwnableUpgradeable {
  using SafeERC20 for IERC20;

  uint8 internal constant LEVERAGE_PRECISION = 10; // 10 = 1x
  uint16 internal constant PERCENT_PRECISION = 10000; // 100.00%

  ILendingPool public lendingPool;
  IAaveProtocolDataProvider public dataProvider;

  IBorrowFlashLoanReceiver public borrowReceiver;
  IRepayFlashLoanReceiver public repayReceiver;
  uint8 private maxLeverage;
  uint8 private minLeverage;

  error ZeroAddress();
  error LeverageOutOfRange();
  error SameAsset();
  error ZeroCollateralAmount();
  error InsufficientAllowance();

  struct FlashBorrowLocalVars {
    address sender;
    address leverager;
    uint256 depositAmount;
    uint256 borrowAmount;
    uint16 ltv;
    uint16 flashLoanFee;
  }

  struct SwapData {
    address to;
    bytes data;
  }

  function initialize(
    ILendingPoolAddressesProvider provider,
    IBorrowFlashLoanReceiver _borrowReceiver,
    IRepayFlashLoanReceiver _repayReceiver
  ) public initializer {
    if (address(provider) == address(0)) revert ZeroAddress();
    if (address(_borrowReceiver) == address(0)) revert ZeroAddress();
    if (address(_repayReceiver) == address(0)) revert ZeroAddress();
    lendingPool = ILendingPool(provider.getLendingPool());
    dataProvider = IAaveProtocolDataProvider(
      provider.getAddress(0x0100000000000000000000000000000000000000000000000000000000000000)
    );
    borrowReceiver = _borrowReceiver;
    repayReceiver = _repayReceiver;
    maxLeverage = 100; // 10x
    minLeverage = 10; // 1x

    __Ownable_init();
  }

  function flashBorrow(
    address collateralAsset,
    uint256 collateralAmount,
    address borrowAsset,
    uint256 borrowAmount,
    uint8 leverage,
    SwapData memory swapData
  ) external {
    if (leverage < minLeverage || leverage > maxLeverage) revert LeverageOutOfRange();
    if (collateralAsset == borrowAsset) revert SameAsset();
    if (collateralAmount == 0) revert ZeroCollateralAmount();
    FlashBorrowLocalVars memory vars;
    vars.sender = _msgSender();
    vars.leverager = address(this);
    uint256 allowance = IERC20(collateralAsset).allowance(vars.sender, vars.leverager);
    if (allowance < collateralAmount) revert InsufficientAllowance();
    IERC20(collateralAsset).safeTransferFrom(vars.sender, vars.leverager, collateralAmount);
    IERC20(collateralAsset).safeTransfer(address(borrowReceiver), collateralAmount);
    uint256 depositAmount = (collateralAmount * leverage) / LEVERAGE_PRECISION;
    uint256 flashLoanAmount = depositAmount - collateralAmount;
    bytes memory params = abi.encode(depositAmount, borrowAsset, borrowAmount, vars.sender, swapData.to, swapData.data);
    borrowReceiver.requestFlashLoan(vars.sender, collateralAsset, flashLoanAmount, params);
  }

  function flashRepay(
    address asset,
    uint256 amount,
    address swapAsset,
    uint256 swapAmount,
    SwapData memory swapData
  ) external {
    address sender = _msgSender();
    bytes memory params = abi.encode(swapAsset, swapAmount, sender, swapData.to, swapData.data);
    repayReceiver.requestFlashLoan(sender, asset, amount, params);
  }
}
