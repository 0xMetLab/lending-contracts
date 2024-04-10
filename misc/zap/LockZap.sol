// SPDX-License-Identifier: MIT
pragma solidity 0.8.12;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {Initializable} from '../../dependencies/openzeppelin/upgradeability/Initializable.sol';
import {OwnableUpgradeable} from '../../dependencies/openzeppelin/upgradeability/OwnableUpgradeable.sol';
import {PausableUpgradeable} from '../../dependencies/openzeppelin/upgradeability/PausableUpgradeable.sol';
import {DustRefunder} from './DustRefunder.sol';
import {IMultiFeeDistribution} from '../../interfaces/IMultiFeeDistribution.sol';
import {IWETH} from '../../interfaces/IWETH.sol';
import {IMultipool} from '../../interfaces/IMultipool.sol';

contract LockZap is Initializable, OwnableUpgradeable, PausableUpgradeable, DustRefunder {
  using SafeERC20 for IERC20;

  IMultiFeeDistribution public mfd;
  IMultipool public multipool;
  IERC20 public met;
  IWETH public weth;

  // Events
  event MultipoolUpdated(address indexed _multipoolAddr);
  event MfdUpdated(address indexed _mfdAddr);
  event Zapped(
    uint256 _assetAmount,
    uint256 _metAmount,
    address indexed _from,
    address indexed _onBehalf,
    uint256 _lockTypeIndex
  );

  // Errors
  error AddressZero();
  error InvalidAsset();
  error AmountZero();
  error InvalidLockLength();

  function initialize(IMultiFeeDistribution _mfd, IMultipool _multipool, IERC20 _met, IWETH _weth) public initializer {
    if (address(_mfd) == address(0)) revert AddressZero();
    if (address(_multipool) == address(0)) revert AddressZero();
    if (address(_met) == address(0)) revert AddressZero();
    if (address(_weth) == address(0)) revert AddressZero();
    address token0 = _multipool.token0();
    address token1 = _multipool.token1();
    if (address(_met) != token0 && address(_met) != token1) revert InvalidAsset();
    if (address(_weth) != token0 && address(_weth) != token1) revert InvalidAsset();

    mfd = _mfd;
    multipool = _multipool;
    met = _met;
    weth = _weth;

    __Ownable_init();
    __Pausable_init();
  }

  /**
   * @notice Zap tokens to stake LP
   * @param _asset The asset to zap
   * @param _assetAmount The amount of asset to zap
   * @param _metAmount The amount of MET to zap
   * @param _lockTypeIndex The index of the lock type
   * @return liquidity The amount of LP tokens received
   */
  function zap(
    address _asset,
    uint256 _assetAmount,
    uint256 _metAmount,
    uint256 _lockTypeIndex
  ) public payable whenNotPaused returns (uint256 liquidity) {
    liquidity = _zap(_asset, _assetAmount, _metAmount, msg.sender, msg.sender, _lockTypeIndex, msg.sender);
  }

  /**
   * @notice Zap tokens to stake LP on behalf of another address
   * @dev It will use default lock index
   * @param _asset The asset to zap
   * @param _assetAmount The amount of asset to zap
   * @param _metAmount The amount of MET to zap
   * @param _onBehalf The address to zap on behalf of
   * @return liquidity The amount of LP tokens received
   */
  function zapOnBehalf(
    address _asset,
    uint256 _assetAmount,
    uint256 _metAmount,
    address _onBehalf
  ) public payable whenNotPaused returns (uint256 liquidity) {
    uint256 _lockTypeIndex = mfd.defaultLockIndex(_onBehalf);
    liquidity = _zap(_asset, _assetAmount, _metAmount, msg.sender, _onBehalf, _lockTypeIndex, _onBehalf);
  }

  /**
   * @notice Zap tokens from vesting to stake LP
   * @param _asset The asset to zap
   * @param _assetAmount The asset to zap
   * @param _lockTypeIndex The index of the lock type. cannot be shortest option (index 0)
   * @return liquidity The amount of LP tokens received
   */
  function zapFromVesting(
    address _asset,
    uint256 _assetAmount,
    uint256 _lockTypeIndex
  ) public payable whenNotPaused returns (uint256 liquidity) {
    if (_lockTypeIndex == 0) revert InvalidLockLength();
    uint256 _metAmount = mfd.zapVestingToLp(msg.sender);
    liquidity = _zap(_asset, _assetAmount, _metAmount, address(this), msg.sender, _lockTypeIndex, msg.sender);
  }

  /**
   * @notice Zap tokens to stake LP
   * @param _asset  The asset to zap
   * @param _assetAmount The amount of asset to zap
   * @param _metAmount The amount of MET to zap
   * @param _from The address to zap from
   * @param _onBehalf The address to zap on behalf of
   * @param _lockTypeIndex The index of the lock type
   * @param _refundAddress The address to refund dust to
   * @return liquidity The amount of LP tokens received
   */
  function _zap(
    address _asset,
    uint256 _assetAmount,
    uint256 _metAmount,
    address _from,
    address _onBehalf,
    uint256 _lockTypeIndex,
    address _refundAddress
  ) internal returns (uint256 liquidity) {
    if (_asset == address(0)) {
      _asset = address(weth);
    }
    if (_asset != address(weth)) revert InvalidAsset();
    if (msg.value > 0) {
      _assetAmount = msg.value;
      weth.deposit{value: _assetAmount}();
    }
    if (_assetAmount == 0) revert AmountZero();
    IERC20(_asset).safeTransferFrom(msg.sender, address(this), _assetAmount);
    IERC20(_asset).forceApprove(address(multipool), _assetAmount);
    // _from == this when zapping from vesting
    if (_from != address(this)) {
      met.safeTransferFrom(msg.sender, address(this), _metAmount);
    }
    met.forceApprove(address(multipool), _metAmount);
    address token0 = multipool.token0();
    address token1 = multipool.token1();
    uint256 amount0Desired = token0 == _asset ? _assetAmount : _metAmount;
    uint256 amount1Desired = token1 == _asset ? _assetAmount : _metAmount;
    liquidity = multipool.deposit(amount0Desired, amount1Desired, address(this), 0);
    IERC20(multipool.multipoolToken()).forceApprove(address(mfd), liquidity);
    mfd.stake(liquidity, _onBehalf, _lockTypeIndex);
    emit Zapped(_assetAmount, _metAmount, _from, _onBehalf, _lockTypeIndex);
    _refundDust(address(met), _asset, _refundAddress);
  }

  receive() external payable {}

  // === Setters ===

  /**
   * @notice Set the Multipool contract address
   * @param _multipoolAddr Multipool contract address
   */
  function setMultipool(address _multipoolAddr) external onlyOwner {
    if (_multipoolAddr == address(0)) revert AddressZero();
    multipool = IMultipool(_multipoolAddr);
    emit MultipoolUpdated(_multipoolAddr);
  }

  /**
   * @notice Set the MultiFeeDistribution contract address
   * @param _mfdAddr MultiFeeDistribution contract address
   */
  function setMfd(address _mfdAddr) external onlyOwner {
    if (_mfdAddr == address(0)) revert AddressZero();
    mfd = IMultiFeeDistribution(_mfdAddr);
    emit MfdUpdated(_mfdAddr);
  }

  /**
   * @notice Pause zapping operation.
   */
  function pause() external onlyOwner {
    _pause();
  }

  /**
   * @notice Unpause zapping operation.
   */
  function unpause() external onlyOwner {
    _unpause();
  }
}
