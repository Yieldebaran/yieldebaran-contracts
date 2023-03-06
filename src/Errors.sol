// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

error UnintendedAction();
error WithdrawalRequestsNotFulfilled();
error NotEnoughBalance();
error NotEnoughFunds();
error QueuedOrFulfilled();
error AlreadyFulfilled();
error AuthFailed();
error AlreadyRequested();
error RequestNotFound();
error TooManyPools();
error AllocationAlreadyExists(address);
error IncorrectUnderlying();
error DisabledAllocation(address);
error NonEmptyAllocation(address);
error EarlyClaim();
error IncorrectArgument();
error OnlyInstantWithdrawals();
