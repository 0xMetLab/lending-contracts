// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.12;

interface IPriceGetter {
  function getPrice() external view returns (uint price);
}
