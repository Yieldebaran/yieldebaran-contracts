// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "forge-std/Test.sol";
import "forge-std/Vm.sol";
import "forge-std/console2.sol";
import {EfficientlyAllocatingPool} from "../src/EfficientlyAllocatingPool.sol";
import {IERC20, SafeERC20} from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import {AllocationConfig} from "../src/AllocationConfig.sol";
import {DelayedWithdrawalTool} from "../src/DelayedWithdrawalTool.sol";
import {Allocator} from "../src/Allocator.sol";
import {EfficientlyAllocatingPoolTest} from "./EfficientlyAllocatingPool.t.sol";
import {RewardManager1inchFantom} from "../src/RewardManager1inchFantom.sol";

abstract contract EfficientlyAllocatingPoolCantoTest is EfficientlyAllocatingPoolTest {
    string rpcUrl = vm.envString("CANTO_RPC_URL");

    function _encodeClaim(address _pool, uint88 _amount, uint8 _index) internal pure returns (bytes32) {
        bytes memory data = abi.encodePacked(_pool, _amount, _index);
        return bytes32(data);
    }

    function _advanceTime(uint256 period) internal override {
        vm.roll(block.number + period);
        skip(period);
    }

    function _encodeScreamToUnderlyingSwap(uint256 _amount, address _destReceiver)
        internal
        pure
        virtual
        returns (bytes memory res)
    { _amount; _destReceiver; return res; }
}
