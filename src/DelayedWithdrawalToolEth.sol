// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import {IERC20, SafeERC20} from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import {DelayedWithdrawalTool} from "./DelayedWithdrawalTool.sol";
import {IWETH} from "./IWETH.sol";
import {IEfficientlyAllocatingPoolEth} from "./interfaces/IEfficientlyAllocatingPoolEth.sol";
import {IDelayedWithdrawalToolEth} from "./interfaces/IDelayedWithdrawalToolEth.sol";
import "./Errors.sol";

contract DelayedWithdrawalToolEth is DelayedWithdrawalTool, IDelayedWithdrawalToolEth {
    receive() external payable {
        if (msg.sender != underlying) revert AuthFailed();
    }

    constructor(address _pool, address _underlying) DelayedWithdrawalTool(_pool, _underlying) {}

    // request owner is msg.sender
    // beneficiary is msg.sender
    function claimEth() external override {
        claimEthFor(msg.sender);
    }

    // request owner is _onBehalfOf
    // beneficiary is _onBehalfOf
    function claimEthFor(address _onBehalfOf) public override {
        (uint256 underlyingAmount, uint256 sharesAmount, uint256 index) = _setClaimed(_onBehalfOf);
        IWETH(underlying).withdraw(underlyingAmount);
        payable(_onBehalfOf).transfer(underlyingAmount);
        emit Claimed(_onBehalfOf, _onBehalfOf, index, underlyingAmount, sharesAmount);
    }

    // request owner is msg.sender
    // beneficiary is _onBehalfOf
    function claimEthTo(address _onBehalfOf) public override {
        (uint256 underlyingAmount, uint256 sharesAmount, uint256 index) = _setClaimed(msg.sender);
        IWETH(underlying).withdraw(underlyingAmount);
        payable(_onBehalfOf).transfer(underlyingAmount);
        emit Claimed(msg.sender, _onBehalfOf, index, underlyingAmount, sharesAmount);
    }

    function instantWithdrawalEth() external override {
        _instantWithdrawalEthFromTo(msg.sender, msg.sender);
    }

    function instantWithdrawalEthFor(address _account) external override {
        _instantWithdrawalEthFromTo(_account, _account);
    }

    // request owner is msg.sender
    // beneficiary is _onBehalfOf
    function instantWithdrawalEthTo(address _onBehalfOf) external override {
        _instantWithdrawalEthFromTo(msg.sender, _onBehalfOf);
    }

    /// @dev withdraws funds from allocations with 0 fee if an allocator hasn't fulfilled request within the time limit
    function _instantWithdrawalEthFromTo(address _requestOwner, address _beneficiary) internal {
        uint index = requestIndex[_requestOwner];
        if (index == 0) revert RequestNotFound();
        if (fulfillmentIndex > index + 1) revert AlreadyFulfilled();
        if (requestTime[_requestOwner] + requestTimeLimit > block.timestamp) revert EarlyClaim();

        uint sharesAmount = sharesRequested[_requestOwner];
        uint underlyingAmount = underlyingRequested[_requestOwner];

        totalSharesRequested[index + 1] -= sharesAmount;
        totalUnderlyingRequested[index + 1] -= underlyingAmount;

        delete requestIndex[_requestOwner];
        delete underlyingRequested[_requestOwner];
        delete sharesRequested[_requestOwner];
        delete requestTime[_requestOwner];

        IEfficientlyAllocatingPoolEth(payable(pool)).instantWithdrawalEth(sharesAmount, 0, _beneficiary);
    }
}
