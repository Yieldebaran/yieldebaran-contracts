// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import {IERC20, SafeERC20} from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import {ReservesAccounting} from "./ReservesAccounting.sol";
import {CalldataDecoder} from "./CalldataDecoder.sol";
import {IDelayedWithdrawalTool} from "./interfaces/IDelayedWithdrawalTool.sol";
import {IEfficientlyAllocatingPool} from "./interfaces/IEfficientlyAllocatingPool.sol";
import "./Errors.sol";

contract EfficientlyAllocatingPool is ReservesAccounting, IEfficientlyAllocatingPool {
    using CalldataDecoder for bytes32;
    using SafeERC20 for IERC20;

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
        ReservesAccounting(
            _underlying,
            _name,
            _symbol,
            _allocator,
            _rewardManager,
            _timeLock,
            _emergencyTimeLock,
            _withdrawTool,
            _allocations,
            _platformAdapters
        )
    {}

    /// @dev performs liquidity reallocation
    /// @notice it's not possible to reallocate without fulfilling all withdrawal requests
    /// @notice can't rug pull since can only interact with pre-approved allocations/adapters
    function allocate(bytes32[] calldata _allocationConfigs) external override onlyAllocator {
        address _underlying = underlying;
        bool isWithdrawalRequested = IDelayedWithdrawalTool(withdrawTool).isRequested();
        for (uint256 i; i < _allocationConfigs.length;) {

            (address allocation, uint88 amount, bool isRedeem, bool useFullBalance) =
                _allocationConfigs[i].decodeAllocation();

            // on first deposit
            if (isWithdrawalRequested && !isRedeem) {
                // fulfill queued withdrawal requests if any
                _fulfillWithdrawalRequestsOnAllocation();
                isWithdrawalRequested = false;
            }
            address platformAdapter = platformAdapter[allocation];

            // don't check `platformAdapter` to save gas
            // anyway it would revert if something goes wrong
            if (isRedeem) {
                _withdraw(platformAdapter, allocation, amount);
            } else {
                _deposit(
                    platformAdapter,
                    _underlying,
                    allocation,
                    useFullBalance ? IERC20(_underlying).balanceOf(address(this)) : uint256(amount)
                );
            }
            unchecked {
                ++i;
            }
        }

        // fulfill requests if there were no deposits
        if (isWithdrawalRequested) {
            _fulfillWithdrawalRequestsOnAllocation();
        }
    }

    function claimRewards(address _allocation) external override nonReentrant {
        address platformAdapter = platformAdapter[_allocation];
        if (platformAdapter == address(0)) revert IncorrectArgument();
        _claimReward(platformAdapter, _allocation);
    }

    /// @notice can be used to claim additional liquidity incentives and so on
    function pullToken(address _token, address _to)
        external
        override
        onlyRewardManager
        nonReentrant
        returns (uint256 amountPulled)
    {
        if (platformAdapter[_token] != address(0) || _token == underlying) revert UnintendedAction();
        if (address(0) == _token) {
            amountPulled = address(this).balance;
            payable(_to).transfer(amountPulled);
        } else {
            amountPulled = IERC20(_token).balanceOf(address(this));
            IERC20(_token).safeTransfer(_to, amountPulled);
        }
    }

    // view allocation balance
    /// @dev change ABI to `constant`
    function sharesBalanceOfPool(address _allocation) external override returns (uint256) {
        return _balance(platformAdapter[_allocation], _allocation);
    }
}
