// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

import {Initializable} from '../../dependencies/openzeppelin/upgradeability/Initializable.sol';
import {OwnableUpgradeable} from '../../dependencies/openzeppelin/upgradeability/OwnableUpgradeable.sol';
import {IChainlinkAdapter} from '../../interfaces/IChainlinkAdapter.sol';
import {IPriceProvider} from '../../interfaces/IPriceProvider.sol';
import {IOracle} from '../../interfaces/IOracle.sol';

/// @title WagmiPriceProvider Contract
/// @author Wagmi team
/// @notice This contract is used to provide price data to the system
contract WagmiPriceProvider is IPriceProvider, Initializable, OwnableUpgradeable {
  IOracle public lpOracle;
  IOracle public rtOracle;
  IChainlinkAdapter public wethOracle;

  error ZeroAddress();

  function initialize(IOracle _lpOracle, IOracle _rtOracle, IChainlinkAdapter _wethOracle) public initializer {
    if (address(_lpOracle) == address(0) || address(_rtOracle) == address(0) || address(_wethOracle) == address(0)) {
      revert ZeroAddress();
    }
    lpOracle = _lpOracle;
    rtOracle = _rtOracle;
    wethOracle = _wethOracle;
    __Ownable_init();
  }

  function getTokenPrice() external view returns (uint256) {
    uint256 wethPrice = wethOracle.latestAnswer();
    uint256 rtPrice = rtOracle.peekSpot('0x');
    return rtPrice / wethPrice / 1e2;
  }

  function getTokenPriceUsd() external view returns (uint256) {
    uint256 rtPrice = rtOracle.peekSpot('0x');
    uint8 rtPriceDecimals = rtOracle.decimals();
    return (rtPrice * 10 ** 8) / (10 ** rtPriceDecimals);
  }

  function getLpTokenPrice() external view returns (uint256) {
    uint256 wlpPrice = lpOracle.peekSpot('0x');
    uint256 wethPrice = wethOracle.latestAnswer();
    return wlpPrice / wethPrice / 1e2;
  }

  function getLpTokenPriceUsd() external view returns (uint256) {
    uint256 wlpPrice = lpOracle.peekSpot('0x');
    uint8 wlpPriceDecimals = lpOracle.decimals();
    return (wlpPrice * 10 ** 8) / (10 ** wlpPriceDecimals);
  }

  function decimals() external pure returns (uint256) {
    return 8;
  }

  function update() external override {}
}
