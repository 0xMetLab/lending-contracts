// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

interface IMultipool {
  function multipoolToken() external view returns (address);

  function token0() external view returns (address);

  function token1() external view returns (address);

  /**
   * @notice Deposit function for adding liquidity to the pool
   * @dev This function allows a user to deposit `amount0Desired` and `amount1Desired` amounts of token0 and token1
   *      respectively into the liquidity pool and receive `lpAmount` amount of corresponding liquidity pool
   *      tokens in return. It first checks if the pool has been initialized, meaning there's already
   *      then it requires that the first deposit be made by the owner address.
   *      If initialized, the optimal amount of tokento be deposited is calculated based on existing reserves and
   *      minimums specified. Then, the amount of LP tokens to be minted is calculated, and the tokens are
   *      transferred accordingly from the caller to the contract. Finally, the deposit function is called internally,
   *      which uses Uniswap V3's mint function to add the liquidity to the pool.
   * @param amount0Desired The amount of token0 desired to deposit.
   * @param amount1Desired The amount of token1 desired to deposit.
   * @param recipient The address to which lp tokens will be minted.
   * @param lpAmountMin The minimum acceptable amount of liquidity tokens to be minted.
   * @return lpAmount Returns the amount of liquidity tokens created.
   */
  function deposit(
    uint256 amount0Desired,
    uint256 amount1Desired,
    address recipient,
    uint256 lpAmountMin
  ) external returns (uint256 lpAmount);
}
