// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

library Downcasts {
  function toUint128(uint256 x) public pure returns (uint128 y) {
    require((y = uint128(x)) == x, "Downcasts: value doesn't fit in 128 bits");
  }
}