// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import {IERC20, SafeERC20} from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import {IReserveAccounting} from "./interfaces/IReserveAccounting.sol";
import {IDelayedWithdrawalTool} from "./interfaces/IDelayedWithdrawalTool.sol";
import "./Errors.sol";

contract DelayedWithdrawalTool is IDelayedWithdrawalTool {
    using SafeERC20 for IERC20;

    mapping (uint256 => uint256) public override totalUnderlyingRequested;
    mapping (uint256 => uint256) public override totalSharesRequested;

    uint256 public override fulfillmentIndex = 1;

    address public immutable override pool;
    address public immutable override underlying;

    uint256 public override requestTimeLimit;

    mapping(address => uint256) public override underlyingRequested;
    mapping(address => uint256) public override sharesRequested;
    mapping(address => uint256) public override requestIndex;
    mapping(address => uint256) public override requestTime;

    event Requested(address indexed user, uint256 index, uint256 shares, uint256 amount);
    event Fulfilled(uint256 shares, uint256 amount, uint256 index);
    event Claimed(address indexed account, address indexed onBehalfOf, uint256 index, uint256 underlyingAmount, uint256 sharesAmount);
    event Cancelled(address indexed user, uint256 index, uint256 amount);
    event RequestTimeLimit(uint256 requestTimeLimit);

    modifier onlyPool() {
        if (msg.sender != pool) revert AuthFailed();
        _;
    }

    constructor(address _pool, address _underlying) {
        pool = _pool;
        underlying = _underlying;
        requestTimeLimit = 2 days;
        emit RequestTimeLimit(2 days);
    }

    function setRequestTimeLimit(uint256 _requestTimeLimit) external override onlyPool {
        requestTimeLimit = _requestTimeLimit;
        emit RequestTimeLimit(_requestTimeLimit);
    }

    function getAmountsToFulfill() external override view returns (uint256 sharesAmount, uint256 underlyingAmount) {
        return (totalSharesRequested[fulfillmentIndex],totalUnderlyingRequested[fulfillmentIndex]);
    }

    /// @return bool - whether are there queued unfulfilled requests or not
    function isRequested() external override view returns (bool) {
        return totalSharesRequested[fulfillmentIndex] != 0 || totalSharesRequested[fulfillmentIndex + 1] != 0;
    }

    /// @notice managed by pool, restricted to interact
    /// @notice in order to request withdrawal use `requestWithdrawal` function of the Pool contract
    function request(address _account, uint256 _shares, uint256 _amount) external override onlyPool {
        // prevents double requests, but can be re-requested after the cancellation
        if (requestIndex[_account] != 0) revert AlreadyRequested();

        uint256 index = fulfillmentIndex;

        totalSharesRequested[index + 1] += _shares;
        totalUnderlyingRequested[index + 1] += _amount;

        requestIndex[_account] = index;
        requestTime[_account] = block.timestamp;
        sharesRequested[_account] = _shares;
        underlyingRequested[_account] = _amount;

        emit Requested(_account, index, _shares, _amount);
    }

    /// @notice managed by pool, restricted to interact
    function markFulfilled() external override onlyPool {
        // capture current values
        uint index = fulfillmentIndex;
        uint256 sharesAmount = totalSharesRequested[index];
        uint256 underlyingAmount = totalUnderlyingRequested[index];

        // update state
        fulfillmentIndex++;
        delete totalSharesRequested[index];
        delete totalUnderlyingRequested[index];

        // emit event
        emit Fulfilled(sharesAmount, underlyingAmount, index);
    }

    function claim() external override {
        claimFor(msg.sender);
    }

    // request owner is _account
    // beneficiary is _account
    function claimFor(address _account) public override {
        (uint256 underlyingAmount, uint256 sharesAmount, uint256 index) = _setClaimed(_account);
        IERC20(underlying).safeTransfer(_account, underlyingAmount);
        emit Claimed(_account, _account, index, underlyingAmount, sharesAmount);
    }

    // request owner is msg.sender
    // beneficiary is _onBehalfOf
    function claimTo(address _onBehalfOf) public override {
        if (_onBehalfOf == address(this)) revert IncorrectArgument();
        (uint256 underlyingAmount, uint256 sharesAmount, uint256 index) = _setClaimed(msg.sender);
        IERC20(underlying).safeTransfer(_onBehalfOf, underlyingAmount);
        emit Claimed(msg.sender, _onBehalfOf, index, underlyingAmount, sharesAmount);
    }

    /// @dev claims previously requested and fulfilled orders on behalf of specified address
    function _setClaimed(address _account) internal returns (uint256, uint256, uint256) {
        uint256 index = requestIndex[_account];

        if (index == 0) revert RequestNotFound();

        // at least 2 cycles should past to complete the request
        if (index + 1 >= fulfillmentIndex) revert EarlyClaim();

        uint256 underlyingAmount = underlyingRequested[_account];
        uint256 sharesAmount = underlyingRequested[_account];

        delete requestIndex[_account];
        delete underlyingRequested[_account];
        delete sharesRequested[_account];
        delete requestTime[_account];

        return (underlyingAmount, sharesAmount, index);
    }

    /// @dev cancels previously created requests if it's neither fulfilled nor queued
    function cancelRequest() external override {
        uint256 index = requestIndex[msg.sender];
        if (index == 0) revert RequestNotFound();

        // can't cancel if queued for the next cycle or already fulfilled
        if (fulfillmentIndex > index) revert QueuedOrFulfilled();

        // capture current values
        uint256 sharesAmount = sharesRequested[msg.sender];
        uint256 underlyingAmount = underlyingRequested[msg.sender];

        // update state
        delete requestIndex[msg.sender];
        delete underlyingRequested[msg.sender];
        delete sharesRequested[msg.sender];
        delete requestTime[msg.sender];

        totalUnderlyingRequested[index + 1] -= underlyingAmount;
        totalSharesRequested[index + 1] -= sharesAmount;

        // not a safeTransfer since the pool contract is known, moreover, it's written by me
        require(IERC20(pool).transfer(msg.sender, sharesAmount), "transfer failed");

        emit Cancelled(msg.sender, index, underlyingAmount);
    }

    function instantWithdrawal() external override {
        _instantWithdrawalFromTo(msg.sender, msg.sender);
    }

    function instantWithdrawalFor(address _account) external override {
        _instantWithdrawalFromTo(_account, _account);
    }

    // request owner is msg.sender
    // beneficiary is _onBehalfOf
    function instantWithdrawalTo(address _onBehalfOf) external override {
        _instantWithdrawalFromTo(msg.sender, _onBehalfOf);
    }

    /// @dev withdraws funds from allocations with 0 fee if an allocator hasn't fulfilled request within the time limit
    function _instantWithdrawalFromTo(address _requestOwner, address _beneficiary) internal {
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

        IReserveAccounting(pool).instantWithdrawal(sharesAmount, 0, _beneficiary);
    }
}
