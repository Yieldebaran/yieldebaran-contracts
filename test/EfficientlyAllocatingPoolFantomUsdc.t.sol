// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "forge-std/Test.sol";
import "forge-std/Vm.sol";
import "forge-std/console.sol";
import "forge-std/console2.sol";
import {EfficientlyAllocatingPool} from "../src/EfficientlyAllocatingPool.sol";
import {IERC20, SafeERC20} from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20Metadata} from "openzeppelin-contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {AllocationConfig} from "../src/AllocationConfig.sol";
import {DelayedWithdrawalTool} from "../src/DelayedWithdrawalTool.sol";
import {Allocator} from "../src/Allocator.sol";
import {EfficientlyAllocatingPoolFantomTest} from "./EfficientlyAllocatingPoolFantom.t.sol";
import {RewardManager1inchFantom} from "../src/RewardManager1inchFantom.sol";
import {CompoundAdapter} from "../src/Platforms/Compound/CompoundAdapter.sol";
import {TarotAdapter} from "../src/Platforms/Tarot/TarotAdapter.sol";

contract EfficientlyAllocatingPoolFantomUsdcTest is EfficientlyAllocatingPoolFantomTest {
    function setUp() public {
        MIN_TEST_AMOUNT = 100e6;
        MAX_TEST_AMOUNT = 2e12;

        uint256 fork = vm.createFork(rpcUrl);
        vm.selectFork(fork);

        vm.rollFork(55530743);

        deployedContracts++;

        tarotAdapter = address(new TarotAdapter());
        deployedContracts++;

        compoundAdapter = new CompoundAdapter();
        deployedContracts++;

        underlying = 0x04068DA6C83AFCFA0e13ba15A6696662335D5B75;
        precisionError = 10 ** (18 - IERC20Metadata(underlying).decimals());

        string memory _name = "Yieldebaran USDC";
        string memory _symbol = "yUSDC";
        allocator = new Allocator(address(this));
        deployedContracts++;
        address _timeLock = address(this);
        address _emergencyTimeLock = address(this);
        address poolAddress = computeCreateAddress(address(this), deployedContracts + 2);
        withdrawTool = new DelayedWithdrawalTool(poolAddress, underlying);
        deployedContracts++;
        rewardManager = new RewardManager1inchFantom(address(this), address(this));
        deployedContracts++;
        address[] memory _allocations = new address[](5);
        uint256 i = 0;
        _allocations[i++] = 0xDb68f7EB74ddaaB1db4045A071e48e5BA9777d6C;
        _allocations[i++] = 0x710675A9c8509D3dF254792C548555D3D0a69494;
        _allocations[i++] = 0xb564899Ba911c4F6a25A7aecC4B8808A487Dc8c2;
        _allocations[i++] = 0xEe234Eb2919A1dc4b597de618240ec0C14Ef11Ce;

        screamIndex = i;
        _allocations[i++] = 0xCc44A1eDC0E8EcC6DF9703Dee4318B3da66b4F70;

        i = 0;
        address[] memory _platformAdapters = new address[](_allocations.length);
        _platformAdapters[i++] = address(tarotAdapter);
        _platformAdapters[i++] = address(tarotAdapter);
        _platformAdapters[i++] = address(tarotAdapter);
        _platformAdapters[i++] = address(tarotAdapter);
        _platformAdapters[i++] = address(compoundAdapter);

        platformAdapters = _platformAdapters;
        allocations = _allocations;

        eap = new EfficientlyAllocatingPool(
            underlying,
            _name,
            _symbol,
            address(allocator),
            address(rewardManager),
            _timeLock,
            _emergencyTimeLock,
            address(withdrawTool),
            _allocations,
            _platformAdapters
        );
        deployedContracts++;
        assertEq(poolAddress, address(eap));
        eap.setRestrictionPhaseStatus(false);
    }

    function _encodeScreamToUnderlyingSwap(uint256 _amount, address _destReceiver)
        internal
        pure
        override
        returns (bytes memory)
    {
        bytes memory start =
            hex"12aa3caf0000000000000000000000005d0ec1f843c1233d304b96dbde0cab9ec04d71ef000000000000000000000000e0654c8e6fd4d733349ac7e09f6f23da256bf47500000000000000000000000004068da6c83afcfa0e13ba15a6696662335d5b7500000000000000000000000030872e4fc4edbfd7a352bfc2463eb4fae9c09086";
        bytes memory end =
            hex"0000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000001400000000000000000000000000000000000000000000000000000000000000160000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001740000000000000000000000000000000000000000000001560001280000de00a007e5c0d20000000000000000000000000000000000000000000000000000ba00006700206ae4071138002dc6c030872e4fc4edbfd7a352bfc2463eb4fae9c090862b4c76d0dc16be1c31d4c1dc53bf9b45987fc75c0000000000000000000000000000000000000000000000000000000000000001e0654c8e6fd4d733349ac7e09f6f23da256bf47500206ae4071118002dc6c02b4c76d0dc16be1c31d4c1dc53bf9b45987fc75c000000000000000000000000000000000000000000000000000000000000000121be370d5312f44cb42ce377bc9b8a0cef1a4c8300a0f2fa6b6604068da6c83afcfa0e13ba15a6696662335d5b75ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff0000000000000000000000000000000280a06c4eca2704068da6c83afcfa0e13ba15a6696662335d5b751111111254eeb25477b68fb85ed929f73a96058200000000000000000000000000000000";
        return bytes.concat(start, abi.encode(_destReceiver), abi.encode(_amount), end);
    }
}
