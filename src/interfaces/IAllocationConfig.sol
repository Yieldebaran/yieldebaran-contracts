// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;
interface IAllocationConfig {

    function disableAllocation(address _allocation) external;

    function enableAllocation(address _allocation, address _platformAdapter)
    external;

    function enabledAllocations(uint256) external view returns (address);

    function getAllocations() external view returns (address[] memory);

    function platformAdapter(address) external view returns (address);

    function underlying() external view returns (address);
}