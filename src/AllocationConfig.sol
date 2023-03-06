// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import {Auth} from "./Auth.sol";
import {PlatformCaller} from "./Platforms/CallPlatform.sol";
import {IAllocationConfig} from "./interfaces/IAllocationConfig.sol";
import "./Errors.sol";

contract AllocationConfig is Auth, PlatformCaller, IAllocationConfig {
    address[] public override enabledAllocations;
    mapping(address => address) public override platformAdapter;
    address public immutable override underlying;

    event AllocationEnabled(address allocation);
    event AllocationDisabled(address allocation);

    constructor(
        address _underlying,
        address _allocator,
        address _rewardManager,
        address _timeLock,
        address _emergencyTimeLock,
        address[] memory _allocations,
        address[] memory _platformAdapters
    ) Auth(_allocator, _rewardManager, _timeLock, _emergencyTimeLock) {
        underlying = _underlying;
        for (uint256 i; i < _allocations.length;) {
            _enableAllocation(_underlying, _allocations[i], _platformAdapters[i]);
            unchecked {
                ++i;
            }
        }
    }

    function getAllocations() external override view returns (address[] memory) {
        return enabledAllocations;
    }

    function enableAllocation(address _allocation, address _platformAdapter) external override onlyTimeLock {
        _enableAllocation(underlying, _allocation, _platformAdapter);
    }

    function _enableAllocation(address _underlying, address _allocation, address _platformAdapter) internal {
        if (enabledAllocations.length == 50) revert TooManyPools();
        if (platformAdapter[_allocation] != address(0)) revert AllocationAlreadyExists(_allocation);

        address _underlyingOfAllocation = _getUnderlying(_platformAdapter, _allocation);
        if (_underlyingOfAllocation != _underlying) revert IncorrectUnderlying();

        platformAdapter[_allocation] = _platformAdapter;
        enabledAllocations.push(_allocation);

        emit AllocationEnabled(_allocation);
    }

    function disableAllocation(address _allocation) external override onlyAdmin {
        address adapter = platformAdapter[_allocation];
        if (adapter == address(0)) revert DisabledAllocation(_allocation);
        delete platformAdapter[_allocation];

        uint256 poolIndex;
        uint256 lastPoolIndex = enabledAllocations.length - 1;
        for (uint256 i; i <= lastPoolIndex;) {
            if (enabledAllocations[i] == _allocation) {
                poolIndex = i;
                break;
            }
            unchecked {
                ++i;
            }
        }

        enabledAllocations[poolIndex] = enabledAllocations[lastPoolIndex];
        enabledAllocations.pop();

        // check balance
        uint256 balance = _calculateUnderlyingBalance(adapter, _allocation);

        if (balance != 0) revert NonEmptyAllocation(_allocation);

        emit AllocationDisabled(_allocation);
    }
}
