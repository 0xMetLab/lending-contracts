// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

import {IAaveProtocolDataProvider} from '../../../../interfaces/IAaveProtocolDataProvider.sol';
import {IAaveOracle} from '../../../../interfaces/IAaveOracle.sol';

library Calculator {
  uint8 internal constant LEVERAGE_PRECISION = 10; // 10 = 1x
  uint16 internal constant PERCENT_PRECISION = 10000; // 100.00%

  error ReserveNotActiveOrFrozen(address asset);
  error BorrowingNotEnabled(address asset);

  struct CalculateBorrowLocalVars {
    uint256 collateralDecimals;
    uint256 ltv;
    uint256 borrowDecimals;
    uint256 collateralInUSD;
    uint256 borrowInUSD;
    uint256 borrowAmountInUSD;
    bool collateralIsActive;
    bool collateralIsFrozen;
    bool borrowingEnabled;
    bool borrowIsActive;
    bool borrowIsFrozen;
  }

  function calculateBorrow(
    address collateralAsset,
    uint256 collateralAmount,
    address borrowAsset,
    IAaveProtocolDataProvider dataProvider,
    IAaveOracle priceOracle
  ) internal view returns (uint256 borrowAmount, uint256 collateralPriceInUsd, uint256 borrowPriceInUsd) {
    CalculateBorrowLocalVars memory vars;
    (
      vars.collateralDecimals,
      vars.ltv,
      ,
      ,
      ,
      ,
      ,
      ,
      vars.collateralIsActive,
      vars.collateralIsFrozen
    ) = dataProvider.getReserveConfigurationData(collateralAsset);

    if (!vars.collateralIsActive || vars.collateralIsFrozen) {
      revert ReserveNotActiveOrFrozen(collateralAsset);
    }

    (vars.borrowDecimals, , , , , , vars.borrowingEnabled, , vars.borrowIsActive, vars.borrowIsFrozen) = dataProvider
      .getReserveConfigurationData(borrowAsset);

    if (!vars.borrowIsActive || vars.borrowIsFrozen) {
      revert ReserveNotActiveOrFrozen(borrowAsset);
    }

    if (!vars.borrowingEnabled) {
      revert BorrowingNotEnabled(borrowAsset);
    }
    collateralPriceInUsd = priceOracle.getAssetPrice(collateralAsset);
    borrowPriceInUsd = priceOracle.getAssetPrice(borrowAsset);
    vars.collateralInUSD = (collateralAmount * collateralPriceInUsd) / (10 ** vars.collateralDecimals);
    vars.borrowInUSD = (vars.collateralInUSD * vars.ltv) / PERCENT_PRECISION;
    borrowAmount = (vars.borrowInUSD * (10 ** vars.borrowDecimals)) / borrowPriceInUsd;
    vars.borrowAmountInUSD = (borrowAmount * borrowPriceInUsd) / (10 ** vars.borrowDecimals);
  }
}
