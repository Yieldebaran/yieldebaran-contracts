// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import {IERC20, SafeERC20} from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "openzeppelin-contracts/security/ReentrancyGuard.sol";
import {AllocationConfig} from "./AllocationConfig.sol";
import {SharesOfAllocatedLiquidity} from "./SharesOfAllocatedLiquidity.sol";
import {IDelayedWithdrawalTool} from "./interfaces/IDelayedWithdrawalTool.sol";
import {IReserveAccounting} from "./interfaces/IReserveAccounting.sol";
import "./Errors.sol";

contract ReservesAccounting is AllocationConfig, SharesOfAllocatedLiquidity, ReentrancyGuard, IReserveAccounting {
    using SafeERC20 for IERC20;

    /// @notice whether underlying charge fee on transfer or not
    bool public override underlyingWithFee;

    /// @notice reserves accumulator value
    uint256 public override reserves;

    /// @notice Withdraw Tool contract address
    address public immutable override withdrawTool;

    /// @notice stores the last captured underlying balance
    uint256 public override underlyingBalanceStored;

    /// @notice protocol revenue factor
    uint256 public override reserveFactor = 0.1e18; // 10% initially

    /// @notice applies to fast withdrawals, goes to the pool
    /// @notice introduced to prevent inappropriate reallocations
    uint256 public override complexityWithdrawalFeeFactor = 0.003e18; // 0.3% initially

    event ComplexityFeeFactorSet(uint256 complexityFeeFactor);
    event InstantWithdrawal(address indexed account, address indexed receiver, uint256 shares, uint256 amount);
    event ReserveFactorSet(uint256 reserveFactor);
    event ExchangeRate(uint256 exchangeRate, uint256 reserves);
    event UnderlyingWithFee();
    event Deposit(address indexed payer, address indexed onBehalfOf, uint256 shares, uint256 amount);

    constructor(
        address _underlying,
        string memory _name,
        string memory _symbol,
        address _allocator,
        address _rewardManager,
        address _timeLock,
        address _emergencyTimeLock,
        address _withdrawTool,
        address[] memory _allocations,
        address[] memory _platformAdapters
    )
        SharesOfAllocatedLiquidity(_underlying, _name, _symbol)
        AllocationConfig(
            _underlying,
            _allocator,
            _rewardManager,
            _timeLock,
            _emergencyTimeLock,
            _allocations,
            _platformAdapters
        )
    {
        withdrawTool = _withdrawTool;
    }

    function _calculateUnderlyingBalance() internal returns (uint256) {
        address _underlying = underlying;
        uint256 balanceSum = 0;

        for (uint256 i; i < enabledAllocations.length;) {
            address allocation = enabledAllocations[i];
            balanceSum += _calculateUnderlyingBalance(platformAdapter[allocation], allocation);
            unchecked {
                ++i;
            }
        }

        return IERC20(_underlying).balanceOf(address(this)) + balanceSum;
    }

    function _getExchangeRate() internal returns (uint256) {
        uint256 previousBalance = underlyingBalanceStored;
        uint256 currentBalance = _calculateUnderlyingBalance();

        uint256 supply = totalSupply();
        uint256 eRate;
        if (supply == 0) {
            reserves = currentBalance;
            eRate = 1e18;
        } else {
            // possible small fluctuations
            if (currentBalance > previousBalance) {
                reserves += (currentBalance - previousBalance) * reserveFactor / 1e18;
            }
            eRate = (currentBalance - reserves) * 1e18 / supply;
        }
        underlyingBalanceStored = currentBalance;
        emit ExchangeRate(eRate, reserves);
        return eRate;
    }

    function calculateUnderlyingBalance() public override nonReentrant returns (uint256) {
        _getExchangeRate();
        return underlyingBalanceStored;
    }

    function calculateExchangeRate() public override nonReentrant returns (uint256) {
        return _getExchangeRate();
    }

    function calculateExchangeRatePayable() public override payable nonReentrant returns (uint256) {
        return _getExchangeRate();
    }

    function deposit(uint256 _amount) external override {
        _depositForFrom(msg.sender, msg.sender, _amount);
    }

    function depositFor(uint256 _amount, address _onBehalfOf) external override {
        if (_onBehalfOf == address(this)) revert IncorrectArgument();
        _depositForFrom(msg.sender, _onBehalfOf, _amount);
    }

    function _depositForFrom(address _from, address _onBehalfOf, uint256 _amount) internal allowed nonReentrant {
        if (_amount == 0) revert IncorrectArgument();
        uint256 exchangeRate = _getExchangeRate();

        address _underlying = underlying;

        // capture previous balance
        uint256 balanceBefore = IERC20(_underlying).balanceOf(address(this));
        IERC20(_underlying).safeTransferFrom(_from, address(this), _amount);
        // calculate real deposit amount
        if (IERC20(_underlying).balanceOf(address(this)) - balanceBefore != _amount) {
            if (!underlyingWithFee) {
                underlyingWithFee = true;
                emit UnderlyingWithFee();
            }
            _amount = IERC20(_underlying).balanceOf(address(this)) - balanceBefore;
        }

        underlyingBalanceStored += _amount;

        uint256 shares = _amount * 1e18 / exchangeRate;
        _mint(_onBehalfOf, shares);
        emit Deposit(msg.sender, _onBehalfOf, shares, _amount);
    }

    function instantWithdrawal(uint256 _shares, uint256 _minFromBalance, address _to)
        external
        override
        nonReentrant
        returns (uint256)
    {
        if (_to == address(this)) revert IncorrectArgument();
        uint256 amountToWithdraw = _instantWithdrawal(_shares, _minFromBalance);
        IERC20(underlying).safeTransfer(_to, amountToWithdraw);
        emit InstantWithdrawal(msg.sender, _to, _shares, amountToWithdraw);
        return amountToWithdraw;
    }

    function _instantWithdrawal(uint256 _shares, uint256 _minFromBalance) internal returns (uint256) {
        if (_shares == 0) revert IncorrectArgument();

        // accrue
        uint256 amountBeforeComplexityFee = _shares * _getExchangeRate() / 1e18;

        // burn shares
        _burn(msg.sender, _shares);

        address _underlying = underlying;
        uint256 balanceBeforeRedeem = IERC20(_underlying).balanceOf(address(this));

        if (_minFromBalance > balanceBeforeRedeem) revert NotEnoughBalance();

        uint256 amountToWithdraw;

        // complexity fee stays in the pool and counts as a pool profit
        underlyingBalanceStored -= amountBeforeComplexityFee;

        // perform direct withdrawal if there is enough balance
        if (balanceBeforeRedeem >= amountBeforeComplexityFee) {
            amountToWithdraw = amountBeforeComplexityFee;
        } else {
            uint256 amountToWithdrawFromAllocations;
            unchecked {
                amountToWithdrawFromAllocations = amountBeforeComplexityFee - balanceBeforeRedeem;
            }

            // no withdrawal fee for instant withdrawal through the withdraw tool
            uint256 feeFactor = msg.sender == withdrawTool ? 0 : complexityWithdrawalFeeFactor;

            // total amount to be withdrawn from current allocations
            amountToWithdrawFromAllocations = amountToWithdrawFromAllocations * (1e18 - feeFactor) / 1e18;

            uint256 amountAfterComplexityFee = balanceBeforeRedeem + amountToWithdrawFromAllocations;

            uint256 withdrawn;

            // iterate over allocations and withdraw until the desired amount is reached
            for (uint256 i; i < enabledAllocations.length;) {
                address pool = enabledAllocations[i];
                address adapter = platformAdapter[pool];
                withdrawn += _withdrawWithLimit(adapter, pool, amountToWithdrawFromAllocations - withdrawn);
                if (withdrawn >= amountToWithdrawFromAllocations) {
                    break;
                }
                unchecked {
                    ++i;
                }
            }

            if (amountToWithdrawFromAllocations > withdrawn) revert NotEnoughFunds();

            amountToWithdraw = amountAfterComplexityFee;
        }

        return amountToWithdraw;
    }

    function requestWithdrawal(uint256 _shares, address _to) external override nonReentrant {
        if (underlyingWithFee) revert OnlyInstantWithdrawals();
        if (_shares == 0) revert IncorrectArgument();
        _transfer(msg.sender, withdrawTool, _shares);
        uint256 requestedAmount = _shares * _getExchangeRate() / 1e18;
        IDelayedWithdrawalTool(withdrawTool).request(_to, _shares, requestedAmount);
    }

    function _fulfillWithdrawalRequestsOnAllocation() internal {
        (uint sharesAmount, uint256 underlyingAmount) = IDelayedWithdrawalTool(withdrawTool).getAmountsToFulfill();

        // amount could be 0 if there are no requests for current cycle
        if (sharesAmount != 0) {
            _burn(withdrawTool, sharesAmount);
        }

        if (underlyingAmount != 0) {
            // there will be some leftover underlying balance due to the profit accumulation during the withdrawal period
            // it will be counted as a pool profit
            underlyingBalanceStored -= underlyingAmount;

            IERC20(underlying).safeTransfer(withdrawTool, underlyingAmount);
        }

        IDelayedWithdrawalTool(withdrawTool).markFulfilled();
    }

    function withdrawReserves(address _to) external override onlyReservesManager {
        uint256 _reserves = reserves;
        reserves = 0;
        underlyingBalanceStored -= _reserves;
        require(IERC20(underlying).transfer(_to, _reserves), "transfer failed");
    }

    /**
     *  @notice only timeLock contract is allowed to set the security factor
     *  @notice complexity fee cannot be greater than 1%
     *  @param _complexityWithdrawalFeeFactor the value of the complexity fee applying to withdrawals from allocations
     */
    function setComplexityWithdrawalFeeFactor(uint256 _complexityWithdrawalFeeFactor) external override onlyTimeLock {
        if (_complexityWithdrawalFeeFactor > 0.01e18) revert IncorrectArgument();
        complexityWithdrawalFeeFactor = _complexityWithdrawalFeeFactor;
        emit ComplexityFeeFactorSet(_complexityWithdrawalFeeFactor);
    }

    /**
     *  @notice only admin is allowed to set the reserve factor
     *  @notice reserves factor CAN be changed without prior notice, but will apply only to the future profit
     *  @notice performance fee cannot be greater than 100% of the profit
     */
    function setReserveFactor(uint256 _reserveFactor) external override onlyAdmin {
        if (_reserveFactor > 1e18) revert IncorrectArgument();
        calculateExchangeRate();
        reserveFactor = _reserveFactor;
        emit ReserveFactorSet(_reserveFactor);
    }

    /**
     *  @notice only admin is allowed to set the request time limit
     */
    function setRequestTimeLimit(uint256 _requestTimeLimit) external override onlyAdmin {
        IDelayedWithdrawalTool(withdrawTool).setRequestTimeLimit(_requestTimeLimit);
    }
}
