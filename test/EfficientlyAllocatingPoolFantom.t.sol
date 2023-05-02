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

abstract contract EfficientlyAllocatingPoolFantomTest is EfficientlyAllocatingPoolTest {
    RewardManager1inchFantom public rewardManager;
    address public constant scream = 0xe0654C8e6fd4D733349ac7E09f6f23DA256bF475;

    uint256 screamIndex;

    string rpcUrl = vm.envString("FANTOM_RPC_URL");

//    function testRewardCompounding(uint88 _amount) public {
//        _amount = uint88(bound(_amount, MIN_TEST_AMOUNT, MAX_TEST_AMOUNT));
//        address _allocation = allocations[screamIndex];
//        deal(underlying, address(this), _amount);
//        IERC20(underlying).approve(address(eap), _amount);
//        eap.deposit(_amount);
//
//        address[] memory _eaps = new address[](1);
//        _eaps[0] = address(eap);
//        bytes32[][] memory _configs = new bytes32[][](1);
//        bytes32[] memory _configsFirst = new bytes32[](1);
//        _configsFirst[0] = _encodeAllocation(_allocation, _amount, false, true);
//        _configs[0] = _configsFirst;
//
//        allocator.allocate(_eaps, _configs);
//
//        _advanceTime(7 * 24 * 3600);
//
//        rewardManager.claimScream(address(eap), _allocation);
//        assertGt(IERC20(scream).balanceOf(address(rewardManager)), 0);
//    }

//    function testRewardDistributionOnchain(uint88 _amount) public {
//        _amount = uint88(bound(_amount, MIN_TEST_AMOUNT, MAX_TEST_AMOUNT));
//        address _allocationScream = allocations[screamIndex];
//        deal(underlying, address(this), _amount);
//        IERC20(underlying).approve(address(eap), _amount);
//        eap.deposit(_amount);
//
//        address[] memory _eaps = new address[](1);
//        _eaps[0] = address(eap);
//        bytes32[][] memory _configs = new bytes32[][](1);
//        bytes32[] memory _configsFirst = new bytes32[](1);
//        _configsFirst[0] = _encodeAllocation(_allocationScream, _amount, false, true);
//        _configs[0] = _configsFirst;
//
//        allocator.allocate(_eaps, _configs);
//
//        _advanceTime(7 * 24 * 3600);
//
//        // SCREAM claim
//        bytes32[] memory claimConfigs = new bytes32[](1);
//        claimConfigs[0] = _encodeClaim(address(eap), 0, uint8(screamIndex));
//
//        uint256 balanceBefore = IERC20(underlying).balanceOf(address(eap));
//        rewardManager.distributeRewards(claimConfigs);
//        assertGt(IERC20(underlying).balanceOf(address(eap)) - balanceBefore, 0);
//    }

//    function testRewardDistribution1inch(uint88 _amount) public {
//        _amount = uint88(bound(_amount, MIN_TEST_AMOUNT, MAX_TEST_AMOUNT));
//        address _allocationScream = allocations[screamIndex];
//        deal(underlying, address(this), _amount);
//        IERC20(underlying).approve(address(eap), _amount);
//        eap.deposit(_amount);
//
//        address[] memory _eaps = new address[](1);
//        _eaps[0] = address(eap);
//        bytes32[][] memory _configs = new bytes32[][](1);
//        bytes32[] memory _configsFirst = new bytes32[](1);
//        _configsFirst[0] = _encodeAllocation(_allocationScream, _amount, false, true);
//        _configs[0] = _configsFirst;
//
//        allocator.allocate(_eaps, _configs);
//
//        _advanceTime(7 * 24 * 3600);
//
//        // SCREAM claim
//        uint256 balanceBefore = IERC20(underlying).balanceOf(address(eap));
//        rewardManager.claimScream(address(eap), _allocationScream);
//        uint256 screamAmount = IERC20(scream).balanceOf(address(rewardManager));
//        rewardManager.distributeScream(
//            address(eap), _allocationScream, _encodeScreamToUnderlyingSwap(screamAmount, address(eap))
//        );
//        assertGt(IERC20(underlying).balanceOf(address(eap)) - balanceBefore, 0);
//    }

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
