// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import {IWETH} from "./IWETH.sol";
import {EfficientlyAllocatingPool} from "./EfficientlyAllocatingPool.sol";
import {IERC20, SafeERC20} from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import {IEfficientlyAllocatingPoolEth} from "./interfaces/IEfficientlyAllocatingPoolEth.sol";
import "./Errors.sol";

contract EfficientlyAllocatingPoolEth is EfficientlyAllocatingPool, IEfficientlyAllocatingPoolEth {
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
        EfficientlyAllocatingPool(
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

    receive() external payable {
        if (msg.sender != underlying) revert AuthFailed();
    }

    function instantWithdrawalEth(uint256 _shares, uint256 _minFromBalance, address _to)
        external
        override
        nonReentrant
        returns (uint256)
    {
        uint256 amountWithdrawn = _instantWithdrawal(_shares, _minFromBalance);

        IWETH(underlying).withdraw(amountWithdrawn);
        payable(_to).transfer(amountWithdrawn);

        emit InstantWithdrawal(msg.sender, _to, _shares, amountWithdrawn);
        return amountWithdrawn;
    }
}
