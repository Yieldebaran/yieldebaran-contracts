// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import {IPlatformAdapter} from "./IPlatformAdapter.sol";

contract PlatformCaller {
    function _withdraw(address _adapter, address _allocation, uint256 _amount) internal {
        (bool result,) =
            _adapter.delegatecall(abi.encodeWithSelector(IPlatformAdapter.withdraw.selector, _allocation, _amount));
        require(result, "platform call failed");
    }

    function _withdrawWithLimit(address _adapter, address _allocation, uint256 _limit)
        internal
        returns (uint256 withdrawn)
    {
        (bool result, bytes memory data) = _adapter.delegatecall(
            abi.encodeWithSelector(IPlatformAdapter.withdrawWithLimit.selector, _allocation, _limit)
        );
        require(result, "platform call failed");
        return abi.decode(data, (uint256));
    }

    function _deposit(address _adapter, address _underlying, address _allocation, uint256 _amount) internal {
        (bool result,) = _adapter.delegatecall(
            abi.encodeWithSelector(IPlatformAdapter.deposit.selector, _underlying, _allocation, _amount)
        );
        require(result, "platform call failed");
    }

    function _claimReward(address _adapter, address _allocation) internal {
        (bool result,) =
            _adapter.delegatecall(abi.encodeWithSelector(IPlatformAdapter.claimReward.selector, _allocation));
        require(result, "platform call failed");
    }

    function _getUnderlying(address _adapter, address _allocation) internal returns (address) {
        (bool result, bytes memory data) =
            _adapter.delegatecall(abi.encodeWithSelector(IPlatformAdapter.getUnderlying.selector, _allocation));
        require(result, "platform call failed");
        return abi.decode(data, (address));
        //        return IPlatformAdapter(_adapter).getUnderlying(_allocation);
    }
    /// @dev change ABI to 'constant'

    function _balance(address _adapter, address _allocation) internal returns (uint256) {
        (bool result, bytes memory data) =
            _adapter.delegatecall(abi.encodeWithSelector(IPlatformAdapter.balance.selector, _allocation));
        require(result, "platform call failed");
        return abi.decode(data, (uint256));
    }

    function _calculateUnderlyingBalance(address _adapter, address _allocation) internal returns (uint256) {
        (bool result, bytes memory data) = _adapter.delegatecall(
            abi.encodeWithSelector(IPlatformAdapter.calculateUnderlyingBalance.selector, _allocation)
        );
        require(result, "platform call failed");
        return abi.decode(data, (uint256));
    }
}
