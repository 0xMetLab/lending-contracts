// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

interface IBaseFlashLoanReceiver {
  function getLoanToValue(address asset) external view returns (uint16);

  function getFlashLoanFee() external view returns (uint16);
}
