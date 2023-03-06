// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;
interface IEfficientlyAllocatingPool {
    function allocate(bytes32[] memory _allocationConfigs) external;

    function claimRewards(address _allocation) external;

    function doSomething(address[] memory callees, bytes[] memory data)
    external;

    function pullToken(address _token, address _to)
    external
    returns (uint256 amountPulled);

    function sharesBalanceOfPool(address _allocation)
    external
    returns (uint256);
}