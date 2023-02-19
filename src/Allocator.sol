// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import {IEffectivelyAllocatingPool} from "./interfaces/IEffectivelyAllocatingPool.sol";
import "./Errors.sol";

contract Allocator {
    address public admin = msg.sender;
    address public allocationManager;

    event AdminSet(address admin);
    event AllocationManagerSet(address allocationManager);

    modifier onlyAdmin() {
        if (msg.sender != admin) revert AuthFailed();
        _;
    }

    constructor(address _allocationManager) {
        emit AdminSet(msg.sender);
        allocationManager = _allocationManager;
        emit AllocationManagerSet(_allocationManager);
    }

    function setAllocationManager(address _allocationManager) external onlyAdmin {
        allocationManager = _allocationManager;
        emit AllocationManagerSet(_allocationManager);
    }

    function setAdmin(address _admin) external onlyAdmin {
        admin = _admin;
        emit AdminSet(_admin);
    }

    /// @dev allocation aggregator for all the Effectively Allocating Pools
    function allocate(address[] calldata _pools, bytes32[][] calldata _configs) external {
        if (msg.sender != allocationManager) revert AuthFailed();
        for (uint256 i = 0; i < _configs.length;) {
            IEffectivelyAllocatingPool(_pools[i]).allocate(_configs[i]);
            unchecked {
                ++i;
            }
        }
    }
}
