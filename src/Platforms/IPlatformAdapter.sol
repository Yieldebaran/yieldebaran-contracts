// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

interface IPlatformAdapter {
    function withdraw(address _allocation, uint256 _amount) external;
    function withdrawWithLimit(address _allocation, uint256 _limit) external returns (uint256 withdrawn);
    function deposit(address _underlying, address _allocation, uint256 _amount) external;
    function claimReward(address _allocation) external;
    function getUnderlying(address _allocation) external view returns (address);
    function balance(address _allocation) external view returns (uint256);
    function calculateUnderlyingBalance(address _allocation) external returns (uint256);
}
