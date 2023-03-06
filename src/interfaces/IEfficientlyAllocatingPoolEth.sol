// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;
interface IEfficientlyAllocatingPoolEth {
    function instantWithdrawalEth(uint256 _shares, uint256 _minFromBalance, address _to)
    external
    returns (uint256);
}