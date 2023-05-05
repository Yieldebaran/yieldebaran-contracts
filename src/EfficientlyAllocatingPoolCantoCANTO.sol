// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import {EfficientlyAllocatingPoolEth} from "./EfficientlyAllocatingPoolEth.sol";
import {CSRAssigner} from "./CSRAssigner.sol";

contract EfficientlyAllocatingPoolCantoCANTO is EfficientlyAllocatingPoolEth, CSRAssigner {
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
        address[] memory _platformAdapters,
        uint _tokenId
    )
        EfficientlyAllocatingPoolEth(
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
        CSRAssigner(_tokenId)
    {}
}
