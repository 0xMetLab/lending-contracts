// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

import {SafeMath} from '@openzeppelin/contracts/utils/math/SafeMath.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {ILendingPoolAddressesProvider} from '../../../../interfaces/ILendingPoolAddressesProvider.sol';
import {ILendingPool} from '../../../../interfaces/ILendingPool.sol';
import {IAaveProtocolDataProvider} from '../../../../interfaces/IAaveProtocolDataProvider.sol';
import {IFlashLoanReceiver} from '../../../../lending/flashloan/interfaces/IFlashLoanReceiver.sol';
import {IBaseFlashLoanReceiver} from '../interfaces/IBaseFlashLoanReceiver.sol';
import {IAaveOracle} from '../../../../interfaces/IAaveOracle.sol';

abstract contract BaseFlashLoanReceiver is IBaseFlashLoanReceiver, IFlashLoanReceiver {
  using SafeERC20 for IERC20;
  using SafeMath for uint256;

  uint16 public PERCENT_PRECISION = 10000; // 100.00%

  ILendingPoolAddressesProvider public immutable ADDRESSES_PROVIDER;
  ILendingPool public immutable LENDING_POOL;
  IAaveOracle public immutable PRICE_ORACLE;
  IAaveProtocolDataProvider public immutable DATA_PROVIDER;

  error InconsistentParams();
  error ReserveNotActiveOrFrozen(address asset);
  error BorrowingNotEnabled(address asset);
  error SwapFailed();

  constructor(ILendingPoolAddressesProvider provider) {
    ADDRESSES_PROVIDER = provider;
    LENDING_POOL = ILendingPool(provider.getLendingPool());
    DATA_PROVIDER = IAaveProtocolDataProvider(
      provider.getAddress(0x0100000000000000000000000000000000000000000000000000000000000000)
    );
    PRICE_ORACLE = IAaveOracle(provider.getPriceOracle());
  }

  function getLoanToValue(address asset) public view returns (uint16) {
    (, uint256 ltv, , , , , , , , ) = DATA_PROVIDER.getReserveConfigurationData(asset);
    return uint16(ltv);
  }

  function getFlashLoanFee() public view returns (uint16) {
    return uint16(LENDING_POOL.FLASHLOAN_PREMIUM_TOTAL());
  }
}
