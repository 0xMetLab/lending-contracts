// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

import {IFlashLoanReceiver} from '../../../../lending/flashloan/interfaces/IFlashLoanReceiver.sol';
import {IBaseFlashLoanReceiver} from './IBaseFlashLoanReceiver.sol';

interface IBorrowFlashLoanReceiver is IBaseFlashLoanReceiver, IFlashLoanReceiver {
  function requestFlashLoan(
    address onBehalfOf,
    address borrowAsset,
    uint256 borrowAmount,
    bytes calldata params
  ) external;
}
