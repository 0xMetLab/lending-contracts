// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {OwnableUpgradeable} from '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';
import {ILendingPool} from '../../interfaces/ILendingPool.sol';
import {IEligibilityDataProvider} from '../../interfaces/IEligibilityDataProvider.sol';
import {IChefIncentivesController} from '../../interfaces/IChefIncentivesController.sol';
import {IWETH} from '../../interfaces/IWETH.sol';
import {TransferHelper} from '../libraries/TransferHelper.sol';

/// @title Looping
/// @author MetLab
/// @notice Looping contract
contract Looping is OwnableUpgradeable {
  using SafeERC20 for IERC20;

  /// @notice Ratio Divisor
  uint256 public constant RATIO_DIVISOR = 10000;

  // Max reasonable fee, 1%
  uint256 public constant MAX_REASONABLE_FEE = 100;

  /// @notice Interest rate mode
  uint256 public constant INTEREST_RATE_MODE = 2;

  /// @notice Lending Pool address
  ILendingPool public lendingPool;

  /// @notice EligibilityDataProvider contract address
  IEligibilityDataProvider public eligibilityDataProvider;

  /// @notice ChefIncentivesController contract address
  IChefIncentivesController public cic;

  /// @notice Treasury address
  address public treasury;

  /// @notice Wrapped ETH contract address
  IWETH public weth;

  /// @notice Fee ratio
  uint256 public feePercent;

  // ============ Events ============

  /// @notice Emitted when fee ratio is updated
  event FeePercentUpdated(uint256 indexed _feePercent);

  /// @notice Emitted when treasury is updated
  event TreasuryUpdated(address indexed _treasury);

  // ============ Errors ============
  /// @notice Emitted when address is zero
  error AddressZero();

  /// @notice Emitted when ratio is invalid
  error InvalidRatio();

  /// @notice Disallow a loop count of 0
  error InvalidLoopCount();

  /// @notice Receive not allowed
  error ReceiveNotAllowed();

  /// @notice Fallback not allowed
  error FallbackNotAllowed();

  /**
   * @notice Initialize the contract
   * @param _lendingPool lending pool contract address
   * @param _eligibilityDataProvider eligibility data provider contract address
   * @param _cic ChefIncentivesController contract address
   * @param _weth Wrapped ETH contract address
   * @param _feePercent fee ratio
   * @param _treasury Treasury address
   */
  function initialize(
    ILendingPool _lendingPool,
    IEligibilityDataProvider _eligibilityDataProvider,
    IChefIncentivesController _cic,
    IWETH _weth,
    uint256 _feePercent,
    address _treasury
  ) public initializer {
    if (address(_lendingPool) == address(0)) revert AddressZero();
    if (address(_eligibilityDataProvider) == address(0)) revert AddressZero();
    if (address(_cic) == address(0)) revert AddressZero();
    if (address(_weth) == address(0)) revert AddressZero();
    if (_feePercent > MAX_REASONABLE_FEE) revert InvalidRatio();
    if (_treasury == address(0)) revert AddressZero();

    lendingPool = _lendingPool;
    eligibilityDataProvider = _eligibilityDataProvider;
    cic = _cic;
    weth = _weth;
    feePercent = _feePercent;
    treasury = _treasury;

    __Ownable_init();
  }

  /**
   * @dev Loop the deposit and borrow of an asset
   * @param asset for loop
   * @param amount for the initial deposit
   * @param interestRateMode stable or variable borrow mode
   * @param borrowRatio Ratio of tokens to borrow
   * @param loopCount Repeat count for loop
   * @param isBorrow true when the loop without deposit tokens
   */
  function loop(
    address asset,
    uint256 amount,
    uint256 interestRateMode,
    uint256 borrowRatio,
    uint256 loopCount,
    bool isBorrow
  ) external {
    if (!(borrowRatio > 0 && borrowRatio <= RATIO_DIVISOR)) revert InvalidRatio();
    if (loopCount == 0) revert InvalidLoopCount();
    uint16 referralCode = 0;
    uint256 fee;
    if (!isBorrow) {
      IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);
      fee = (amount * feePercent) / RATIO_DIVISOR;
      if (fee > 0) {
        IERC20(asset).safeTransfer(treasury, fee);
        amount = amount - fee;
      }
    }
    _approve(asset);

    cic.setEligibilityExempt(msg.sender, true);

    if (!isBorrow) {
      lendingPool.deposit(asset, amount, msg.sender, referralCode);
    } else {
      amount = (amount * RATIO_DIVISOR) / borrowRatio;
    }

    for (uint256 i = 0; i < loopCount; ) {
      // Reenable on last deposit
      if (i == (loopCount - 1)) {
        cic.setEligibilityExempt(msg.sender, false);
      }

      amount = (amount * borrowRatio) / RATIO_DIVISOR;
      lendingPool.borrow(asset, amount, interestRateMode, referralCode, msg.sender);

      fee = (amount * feePercent) / RATIO_DIVISOR;
      if (fee > 0) {
        IERC20(asset).safeTransfer(treasury, fee);
        amount = amount - fee;
      }

      lendingPool.deposit(asset, amount, msg.sender, referralCode);
      unchecked {
        i++;
      }
    }
  }

  /**
   * @notice Loop the deposit and borrow of ETH
   * @param interestRateMode interest rate mode
   * @param borrowRatio borrow ratio
   * @param loopCount loop count
   */
  function loopETH(uint256 interestRateMode, uint256 borrowRatio, uint256 loopCount) external payable {
    if (!(borrowRatio > 0 && borrowRatio <= RATIO_DIVISOR)) revert InvalidRatio();
    if (loopCount == 0) revert InvalidLoopCount();
    uint16 referralCode = 0;
    uint256 amount = msg.value;
    _approve(address(weth));

    uint256 fee = (amount * feePercent) / RATIO_DIVISOR;
    if (fee > 0) {
      TransferHelper.safeTransferETH(treasury, fee);
      amount = amount - fee;
    }

    cic.setEligibilityExempt(msg.sender, true);

    weth.deposit{value: amount}();
    lendingPool.deposit(address(weth), amount, msg.sender, referralCode);

    for (uint256 i = 0; i < loopCount; ) {
      // Reenable on last deposit
      if (i == (loopCount - 1)) {
        cic.setEligibilityExempt(msg.sender, false);
      }

      amount = (amount * borrowRatio) / RATIO_DIVISOR;
      lendingPool.borrow(address(weth), amount, interestRateMode, referralCode, msg.sender);

      fee = (amount * feePercent) / RATIO_DIVISOR;
      if (fee > 0) {
        weth.withdraw(fee);
        TransferHelper.safeTransferETH(treasury, fee);
        amount = amount - fee;
      }

      lendingPool.deposit(address(weth), amount, msg.sender, referralCode);
      unchecked {
        i++;
      }
    }
  }

  /**
   * @dev Loop the borrow and deposit of ETH
   * @param amount initial amount to borrow
   * @param interestRateMode stable or variable borrow mode
   * @param borrowRatio Ratio of tokens to borrow
   * @param loopCount Repeat count for loop
   **/
  function loopETHFromBorrow(
    uint256 amount,
    uint256 interestRateMode,
    uint256 borrowRatio,
    uint256 loopCount
  ) external {
    if (!(borrowRatio > 0 && borrowRatio <= RATIO_DIVISOR)) revert InvalidRatio();
    if (loopCount == 0) revert InvalidLoopCount();
    uint16 referralCode = 0;
    _approve(address(weth));

    uint256 fee;

    cic.setEligibilityExempt(msg.sender, true);

    for (uint256 i = 0; i < loopCount; ) {
      // Reenable on last deposit
      if (i == (loopCount - 1)) {
        cic.setEligibilityExempt(msg.sender, false);
      }

      lendingPool.borrow(address(weth), amount, interestRateMode, referralCode, msg.sender);

      fee = (amount * feePercent) / RATIO_DIVISOR;
      if (fee > 0) {
        weth.withdraw(fee);
        TransferHelper.safeTransferETH(treasury, fee);
        amount = amount - fee;
      }

      lendingPool.deposit(address(weth), amount, msg.sender, referralCode);

      amount = (amount * borrowRatio) / RATIO_DIVISOR;
      unchecked {
        i++;
      }
    }
  }

  /**
   * @notice Set the CIC contract address
   * @param _cic CIC contract address
   */
  function setChefIncentivesController(IChefIncentivesController _cic) external onlyOwner {
    if (address(_cic) == address(0)) revert AddressZero();
    cic = _cic;
  }

  /**
   * @notice Sets fee ratio
   * @param _feePercent fee ratio
   */
  function setFeePercent(uint256 _feePercent) external onlyOwner {
    if (_feePercent > MAX_REASONABLE_FEE) revert InvalidRatio();
    feePercent = _feePercent;
    emit FeePercentUpdated(_feePercent);
  }

  /**
   * @notice Set the treasury address
   * @param _treasury Treasury address
   */
  function setTreasury(address _treasury) external onlyOwner {
    if (_treasury == address(0)) revert AddressZero();
    treasury = _treasury;
    emit TreasuryUpdated(_treasury);
  }

  /**
   * @notice Approves token allowance of `lendingPool` and `treasury`.
   * @param asset underlyig asset
   **/
  function _approve(address asset) internal {
    if (IERC20(asset).allowance(address(this), address(lendingPool)) == 0) {
      IERC20(asset).forceApprove(address(lendingPool), type(uint256).max);
    }
    if (IERC20(asset).allowance(address(this), address(treasury)) == 0) {
      IERC20(asset).forceApprove(treasury, type(uint256).max);
    }
  }

  /**
   * @dev Only WETH contract is allowed to transfer ETH here. Prevent other addresses to send Ether to this contract.
   */
  receive() external payable {
    if (msg.sender != address(weth)) revert ReceiveNotAllowed();
  }

  /**
   * @dev Revert fallback calls
   */
  fallback() external payable {
    revert FallbackNotAllowed();
  }
}
