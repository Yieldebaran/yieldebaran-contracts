// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "forge-std/Test.sol";
import "forge-std/Vm.sol";
import "forge-std/console.sol";
import "forge-std/console2.sol";
import {EffectivelyAllocatingPool} from "../src/EffectivelyAllocatingPool.sol";
import {IERC20, SafeERC20} from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import {AllocationConfig} from "../src/AllocationConfig.sol";
import {Address} from "openzeppelin-contracts/utils/Address.sol";
import {DelayedWithdrawalTool} from "../src/DelayedWithdrawalTool.sol";
import {Allocator} from "../src/Allocator.sol";
import {CompoundAdapter} from "../src/Platforms/Compound/CompoundAdapter.sol";
import "../src/Errors.sol";

abstract contract EffectivelyAllocatingPoolTest is Test {
    using stdStorage for StdStorage;

    EffectivelyAllocatingPool public eap;
    Allocator public allocator;
    DelayedWithdrawalTool public withdrawTool;

    address tarotAdapter;
    CompoundAdapter compoundAdapter;

    uint256 public MIN_TEST_AMOUNT;
    uint256 public MAX_TEST_AMOUNT;

    uint256 precisionError;

    uint256 deployedContracts;
    address underlying;
    address[] allocations;
    address[] platformAdapters;

    address bob = makeAddr("bob");

    event Deposit(address indexed payer, address indexed onBehalfOf, uint256 shares, uint256 amount);
    event InstantWithdrawal(address indexed account, address indexed receiver, uint256 shares, uint256 amount);

    event AllocationEnabled(address allocation);
    event AllocationDisabled(address allocation);

    function testFirstDeposit(address _from, uint256 _amount) public {
        vm.assume(_from != address(0) && !Address.isContract(_from));
        _amount = uint88(bound(_amount, MIN_TEST_AMOUNT, MAX_TEST_AMOUNT));
        deal(underlying, _from, _amount);
        hoax(_from);
        IERC20(underlying).approve(address(eap), _amount);
        vm.expectEmit(true, true, false, true);
        emit Deposit(_from, _from, _amount, _amount);
        vm.prank(_from);
        eap.deposit(_amount);
        assertEq(eap.balanceOf(_from), _amount);
    }

    function testAllocate(uint88 _amount, uint256 _i) public {
        _amount = uint88(bound(_amount, MIN_TEST_AMOUNT, MAX_TEST_AMOUNT));
        _i = bound(_i, 0, allocations.length - 1);
        address _allocation = allocations[_i];
        deal(underlying, address(this), _amount);
        IERC20(underlying).approve(address(eap), _amount);
        eap.deposit(_amount);

        address[] memory _pools = new address[](1);
        _pools[0] = address(eap);
        bytes32[][] memory _configs = new bytes32[][](1);
        bytes32[] memory _configsFirst = new bytes32[](1);
        _configsFirst[0] = _encodeAllocation(_allocation, _amount, false, true);
        _configs[0] = _configsFirst;

        allocator.allocate(_pools, _configs);

        _advanceTime(7 * 24 * 3600);

        uint256 exchangeRate = eap.calculateExchangeRate();
        assertGe(exchangeRate, 1e18 - precisionError);
    }

    function testWithdrawReserves(uint88 _amount, uint256 _i) public {
        _amount = uint88(bound(_amount, MIN_TEST_AMOUNT, MAX_TEST_AMOUNT));
        _i = bound(_i, 0, allocations.length - 1);
        address _allocation = allocations[_i];
        deal(underlying, address(this), _amount);
        IERC20(underlying).approve(address(eap), _amount);
        eap.deposit(_amount);

        address[] memory _pools = new address[](1);
        _pools[0] = address(eap);
        bytes32[][] memory _configs = new bytes32[][](1);
        bytes32[] memory _configsFirst = new bytes32[](1);
        _configsFirst[0] = _encodeAllocation(_allocation, _amount, false, true);
        _configs[0] = _configsFirst;

        allocator.allocate(_pools, _configs);

        _advanceTime(7 * 24 * 3600);
        eap.calculateExchangeRate();

        // reallocate to withdraw underlying
        uint256 shares = eap.sharesBalanceOfPool(_allocation);
        _configs[0][0] = _encodeAllocation(_allocation, uint88(shares), true, false);
        allocator.allocate(_pools, _configs);

        uint256 reserves = eap.reserves();

        eap.withdrawReserves(msg.sender);
        assertEq(IERC20(underlying).balanceOf(msg.sender), reserves);
    }

    function testInstantWithdrawal(uint88 _amount, uint256 _i) public {
        _amount = uint88(bound(_amount, MIN_TEST_AMOUNT, MAX_TEST_AMOUNT));
        _i = bound(_i, 0, allocations.length - 1);
        console2.log("initial amount", _amount);
        address _allocation = allocations[_i];
        deal(underlying, address(this), _amount);
        IERC20(underlying).approve(address(eap), _amount);
        eap.deposit(_amount);

        address[] memory _pools = new address[](1);
        _pools[0] = address(eap);
        bytes32[][] memory _configs = new bytes32[][](1);
        bytes32[] memory _configsFirst = new bytes32[](1);
        _configsFirst[0] = _encodeAllocation(_allocation, _amount, false, true);
        _configs[0] = _configsFirst;

        allocator.allocate(_pools, _configs);

        _advanceTime(7 * 24 * 3600);

        eap.calculateExchangeRate();

        uint256 reserves = eap.reserves();

        console2.log("reserves before instant withdrawal", reserves);

        uint256 balanceBefore = IERC20(underlying).balanceOf(address(this));
        eap.instantWithdrawal(_amount, 0, address(this));
        uint256 balanceAfter = IERC20(underlying).balanceOf(address(this));

        // subtract 1 to overcome precision errors
        assertGe(
            balanceAfter - balanceBefore,
            _amount * (1e18 - precisionError) / 1e18 * (1e18 - eap.complexityWithdrawalFeeFactor()) / 1e18
        );

        // reallocate prior reserves withdrawal
        uint256 shares = eap.sharesBalanceOfPool(_allocation);
        _configs[0][0] = _encodeAllocation(_allocation, uint88(shares), true, false);
        allocator.allocate(_pools, _configs);

        console2.log("total supply", eap.totalSupply());

        // sync
        eap.calculateExchangeRate();

        reserves = eap.reserves();
        console2.log("reserves after instant withdrawal and exchange rate update", reserves);
        console2.log("balance after instant withdrawal", IERC20(underlying).balanceOf(address(eap)));
        uint256 reservesReceiverBalanceBefore = IERC20(underlying).balanceOf(msg.sender);
        eap.withdrawReserves(msg.sender);
        assertEq(IERC20(underlying).balanceOf(msg.sender) - reservesReceiverBalanceBefore, reserves);

        int256 earn = int256(balanceAfter - balanceBefore) - int256(int88(_amount));
        console2.log("user balance change result", earn);

        assertEq(IERC20(underlying).balanceOf(address(eap)), 0);
    }

    function testInstantWithdrawal_WithExistentDeposits(uint88 _amount, uint256 _i) public {
        _amount = uint88(bound(_amount, MIN_TEST_AMOUNT, MAX_TEST_AMOUNT));
        _i = bound(_i, 0, allocations.length - 1);
        address _allocation = allocations[_i];

        console2.log("initial amount", _amount);

        // first user deposit
        address user1 = vm.addr(200);
        deal(underlying, user1, _amount);
        hoax(user1);
        IERC20(underlying).approve(address(eap), _amount);
        vm.prank(user1);
        eap.deposit(_amount);

        // allocation
        address[] memory _pools = new address[](1);
        _pools[0] = address(eap);
        bytes32[][] memory _configs = new bytes32[][](1);
        bytes32[] memory _configsFirst = new bytes32[](1);
        _configsFirst[0] = _encodeAllocation(_allocation, _amount, false, true);
        _configs[0] = _configsFirst;

        allocator.allocate(_pools, _configs);

        // advance time
        _advanceTime(1);

        // second user deposit
        deal(underlying, address(this), _amount);
        IERC20(underlying).approve(address(eap), _amount);
        console2.log("underlying balance stored", eap.underlyingBalanceStored());
        eap.deposit(_amount);
        uint256 shares = eap.balanceOf(address(this));

        // advance time
        _advanceTime(7 * 24 * 3600);

        // second user withdrawal
        uint256 balanceBefore = IERC20(underlying).balanceOf(address(this));
        eap.instantWithdrawal(shares, 0, address(this));
        uint256 balanceAfter = IERC20(underlying).balanceOf(address(this));

        // should get at least the initial deposit since contract has enough unallocated funds
        assertGe(balanceAfter - balanceBefore, _amount * (1e18 - precisionError) / 1e18);
        assertEq(eap.balanceOf(address(this)), 0);
    }

    function testInstantWithdrawal_MultiAllocation(uint88 _amount) public {
        _amount = uint88(bound(_amount, MIN_TEST_AMOUNT, MAX_TEST_AMOUNT));
        uint256 _start = 0;
        uint256 _finish = allocations.length - 1;

        deal(underlying, address(this), _amount);
        IERC20(underlying).approve(address(eap), _amount);
        eap.deposit(_amount);

        uint256 poolCount = _finish - _start + 1;
        uint88 amountPerAllocation = _amount / uint88(poolCount);

        address[] memory _pools = new address[](1);
        _pools[0] = address(eap);
        bytes32[][] memory _configs = new bytes32[][](1);
        bytes32[] memory _configForCurrentEap = new bytes32[](poolCount);

        for (uint256 i = 0; i < poolCount; ++i) {
            address _allocation = allocations[_start + i];
            _configForCurrentEap[i] = _encodeAllocation(_allocation, amountPerAllocation, false, i == poolCount - 1);
        }

        _configs[0] = _configForCurrentEap;

        allocator.allocate(_pools, _configs);

        _advanceTime(7 * 24 * 3600);

        eap.calculateExchangeRate();

        uint256 reserves = eap.reserves();

        uint256 balanceBefore = IERC20(underlying).balanceOf(address(this));
        eap.instantWithdrawal(_amount, 0, address(this));
        uint256 balanceAfter = IERC20(underlying).balanceOf(address(this));
        assertGt(balanceAfter - balanceBefore, _amount * (1e18 - eap.complexityWithdrawalFeeFactor()) / 1e18);

        // reallocate prior reserves withdrawal
        for (uint256 i = 0; i < poolCount; ++i) {
            uint256 shares = eap.sharesBalanceOfPool(allocations[_start + i]);
            _configs[0][i] = _encodeAllocation(allocations[_start + i], uint88(shares), true, false);
        }

        allocator.allocate(_pools, _configs);

        // sync
        eap.calculateExchangeRate();
        reserves = eap.reserves();
        assertGt(reserves, 0);
        uint256 reservesReceiverBalanceBefore = IERC20(underlying).balanceOf(msg.sender);
        eap.withdrawReserves(msg.sender);

        assertEq(IERC20(underlying).balanceOf(msg.sender) - reservesReceiverBalanceBefore, reserves);

        int256 earn = int256(balanceAfter - balanceBefore) - int256(int88(_amount));
        console2.log("user balance change result", earn);

        assertEq(IERC20(underlying).balanceOf(address(eap)), 0);
    }

    function testInstantWithdrawal_MultiAllocation_MultiUser(uint88 _amount) public {
        _amount = uint88(bound(_amount, MIN_TEST_AMOUNT, MAX_TEST_AMOUNT));

        uint256 userCount = 20;

        uint88 amountPerUser = _amount / uint88(userCount);

        uint88 totalDeposits = amountPerUser * uint88(userCount);

        // deposit
        for (uint256 i = 0; i < userCount; ++i) {
            address user = vm.addr(i + 1000);
            deal(underlying, user, amountPerUser);
            hoax(user);
            IERC20(underlying).approve(address(eap), amountPerUser);
            vm.prank(user);
            eap.deposit(amountPerUser);
        }

        // allocation
        uint88 amountPerAllocation = totalDeposits / uint88(allocations.length);

        address[] memory _pools = new address[](1);
        _pools[0] = address(eap);
        bytes32[][] memory _configs = new bytes32[][](1);
        bytes32[] memory _configForCurrentEap = new bytes32[](allocations.length);

        for (uint256 i = 0; i < allocations.length; ++i) {
            address _allocation = allocations[i];
            _configForCurrentEap[i] =
                _encodeAllocation(_allocation, amountPerAllocation, false, i == allocations.length - 1);
        }

        _configs[0] = _configForCurrentEap;

        allocator.allocate(_pools, _configs);

        _advanceTime(7 * 24 * 3600);

        // withdraw
        for (uint256 i = 0; i < userCount; ++i) {
            address user = vm.addr(i + 1000);
            uint256 shares = eap.balanceOf(user);
            uint256 expectedReturn = shares * eap.calculateExchangeRate() / 1e18;
            uint256 balanceOnContract = IERC20(underlying).balanceOf(address(eap));
            expectedReturn = balanceOnContract
                + (expectedReturn - balanceOnContract) * (1e18 - eap.complexityWithdrawalFeeFactor()) / 1e18;
            uint256 balanceBefore = IERC20(underlying).balanceOf(user);
            vm.prank(user);
            eap.instantWithdrawal(shares, 0, user);

            // should get at least the deposit amount minus fee
            assertGt(expectedReturn, amountPerUser * (1e18 - eap.complexityWithdrawalFeeFactor()) / 1e18);
            assertEq(IERC20(underlying).balanceOf(user) - balanceBefore, expectedReturn);
        }
    }

    function testDelayedWithdrawals_MultiAllocation_MultiUser(uint88 _amount) public {
        _amount = uint88(bound(_amount, MIN_TEST_AMOUNT, MAX_TEST_AMOUNT));

        uint256 userCount = 20;

        uint88 amountPerUser = _amount / uint88(userCount);

        uint88 totalDeposits = amountPerUser * uint88(userCount);

        // deposit
        for (uint256 i = 0; i < userCount; ++i) {
            address user = vm.addr(i + 1000);
            deal(underlying, user, amountPerUser);
            hoax(user);
            IERC20(underlying).approve(address(eap), amountPerUser);
            vm.prank(user);
            eap.deposit(amountPerUser);
        }

        // allocation
        uint88 amountPerAllocation = totalDeposits / uint88(allocations.length);

        address[] memory _pools = new address[](1);
        _pools[0] = address(eap);
        bytes32[][] memory _configs = new bytes32[][](1);
        bytes32[] memory _configForCurrentEap = new bytes32[](allocations.length);

        for (uint256 i = 0; i < allocations.length; ++i) {
            address _allocation = allocations[i];
            _configForCurrentEap[i] =
                _encodeAllocation(_allocation, amountPerAllocation, false, i == allocations.length - 1);
        }

        _configs[0] = _configForCurrentEap;

        allocator.allocate(_pools, _configs);

        _advanceTime(7 * 24 * 3600);

        uint256 reserves = eap.reserves();

        console2.log("reserves before instant withdrawal", reserves);

        // request
        for (uint256 i = 0; i < userCount; ++i) {
            address user = vm.addr(i + 1000);
            uint256 shares = eap.balanceOf(user);
            vm.prank(user);
            eap.requestWithdrawal(shares, user);
        }

        vm.expectRevert(EarlyClaim.selector);
        withdrawTool.claimFor(vm.addr(1000));

        // reallocate #1
        for (uint256 i = 0; i < allocations.length; ++i) {
            uint256 shares = eap.sharesBalanceOfPool(allocations[i]);
            _configs[0][i] = _encodeAllocation(allocations[i], uint88(shares), true, false);
        }

        allocator.allocate(_pools, _configs);

        // reallocate #2
        _configs[0] = new bytes32[](0);

        allocator.allocate(_pools, _configs);

        console2.log("total supply", eap.totalSupply());
        console2.log("withdrawal tool balance", eap.balanceOf(address(withdrawTool)));

        vm.expectRevert(RequestNotFound.selector);
        withdrawTool.claimFor(makeAddr("bob"));

        // withdrawal
        for (uint256 i = 0; i < userCount; ++i) {
            address user = vm.addr(i + 1000);
            uint256 balanceBefore = IERC20(underlying).balanceOf(user);
            withdrawTool.claimFor(user);
            vm.expectRevert(RequestNotFound.selector);
            withdrawTool.claimFor(user);
            uint256 balanceAfter = IERC20(underlying).balanceOf(user);
            // yield > 0
            assertGt(balanceAfter - balanceBefore, amountPerUser);
        }

        assertEq(eap.totalSupply(), 0);
        assertEq(IERC20(underlying).balanceOf(address(withdrawTool)), 0);

        // sync
        eap.calculateExchangeRate();
        reserves = eap.reserves();
        assertGt(reserves, 0);
        console2.log("reserves after reallocation and exchange rate update", reserves);
        console2.log("underlying balance of EAP after instant withdrawals", IERC20(underlying).balanceOf(address(eap)));
        uint256 reservesReceiverBalanceBefore = IERC20(underlying).balanceOf(msg.sender);
        eap.withdrawReserves(msg.sender);

        vm.expectRevert(AuthFailed.selector);
        vm.prank(vm.addr(20239204));
        eap.withdrawReserves(msg.sender);

        assertEq(IERC20(underlying).balanceOf(msg.sender) - reservesReceiverBalanceBefore, reserves);

        // check no leftover on EAP
        assertEq(IERC20(underlying).balanceOf(address(eap)), 0);
        assertEq(eap.calculateUnderlyingBalance(), 0);
        assertEq(eap.calculateExchangeRate(), 1e18);
    }

    function testExchangeRateChange(uint88 _amount, uint256 _i) public {
        // initial deposit
        _amount = uint88(bound(_amount, MIN_TEST_AMOUNT, MAX_TEST_AMOUNT / 2));
        _i = bound(_i, 0, allocations.length - 1);
        console2.log("initial amount", _amount);
        address _allocation = allocations[_i];
        deal(underlying, address(this), _amount * 2);
        IERC20(underlying).approve(address(eap), _amount * 2);

        // first deposit
        eap.deposit(_amount);

        address[] memory _pools = new address[](1);
        _pools[0] = address(eap);
        bytes32[][] memory _configs = new bytes32[][](1);
        bytes32[] memory _configsFirst = new bytes32[](1);
        _configsFirst[0] = _encodeAllocation(_allocation, _amount, false, true);
        _configs[0] = _configsFirst;

        allocator.allocate(_pools, _configs);

        _advanceTime(7 * 24 * 3600);

        //        for (uint i; i < 10; i ++) {
        //            eap.calculateExchangeRate();
        //            console2.log("%s underlying balance %s", i, eap.underlyingBalanceStored());
        //        }

        uint256 exchangeRate = eap.calculateExchangeRate();

        vm.expectEmit(true, true, false, true);
        emit Deposit(address(this), address(this), uint256(_amount) * 1e18 / exchangeRate, _amount);
        // second deposit
        eap.deposit(_amount);

        uint256 expectedShares = uint256(_amount) + (uint256(_amount) * 1e18 / exchangeRate);

        assertEq(eap.balanceOf(address(this)), expectedShares);
    }

    function testAllocations() public {
        uint256 amount = MAX_TEST_AMOUNT / 2;

        // first deposit
        deal(underlying, address(this), amount * 2);
        IERC20(underlying).approve(address(eap), amount * 2);
        eap.deposit(amount);

        address[] memory _pools = new address[](1);
        _pools[0] = address(eap);
        bytes32[][] memory _configs = new bytes32[][](1);
        bytes32[] memory _configsFirst = new bytes32[](1);

        // don't spend money on unregistered allocations
        _configsFirst[0] = _encodeAllocation(address(this), uint88(amount), false, true);
        _configs[0] = _configsFirst;
        uint256 moneyBefore = IERC20(underlying).balanceOf(address(eap));
        allocator.allocate(_pools, _configs);
        assertEq(IERC20(underlying).balanceOf(address(eap)), moneyBefore);

        _configsFirst[0] = _encodeAllocation(allocations[0], uint88(amount), false, true);
        _configs[0] = _configsFirst;
        allocator.allocate(_pools, _configs);

        // revert attempt to disable allocation with funds
        vm.expectRevert(abi.encodeWithSelector(NonEmptyAllocation.selector, allocations[0]));
        eap.disableAllocation(allocations[0]);

        uint256 lastShares = eap.sharesBalanceOfPool(allocations[0]);

        _configsFirst = new bytes32[](2);

        for (uint256 i = 1; i < allocations.length; ++i) {
            _advanceTime(10);
            console2.log("exchange rate in 10 sec", i, eap.calculateExchangeRate());

            _configsFirst[0] = _encodeAllocation(allocations[i - 1], uint88(lastShares), true, false);
            _configsFirst[1] = _encodeAllocation(allocations[i], uint88(amount), false, true);
            _configs[0] = _configsFirst;

            allocator.allocate(_pools, _configs);

            lastShares = eap.sharesBalanceOfPool(allocations[i]);
        }
    }

    function testAllocationManagement() public {
        address lastAllocation = allocations[allocations.length - 1];

        vm.expectEmit(true, true, false, true);
        emit AllocationDisabled(allocations[0]);
        eap.disableAllocation(allocations[0]);

        assertEq(eap.platformAdapter(allocations[0]), address(0));

        // last allocation moved to the deleted index
        assertEq(eap.enabledAllocations(0), lastAllocation);
        // allocation count decremented
        assertEq(eap.getAllocations().length, allocations.length - 1);

        vm.expectRevert(abi.encodeWithSelector(DisabledAllocation.selector, allocations[0]));
        eap.disableAllocation(allocations[0]);

        vm.expectRevert(abi.encodeWithSelector(AllocationAlreadyExists.selector, allocations[1]));
        eap.enableAllocation(allocations[1], address(tarotAdapter));

        vm.expectEmit(true, true, false, true);
        emit AllocationEnabled(allocations[0]);
        eap.enableAllocation(allocations[0], address(tarotAdapter));

        // allocation count incremented
        assertEq(eap.getAllocations().length, allocations.length);
        assertEq(eap.enabledAllocations(allocations.length - 1), allocations[0]);
        assertEq(eap.platformAdapter(allocations[0]), address(tarotAdapter));
    }

    function testRequestWithdrawal(uint88 _amount, uint256 _i) public {
        _amount = uint88(bound(_amount, MIN_TEST_AMOUNT, MAX_TEST_AMOUNT));
        _i = bound(_i, 0, allocations.length - 1);
        console2.log("initial amount", _amount);
        address _allocation = allocations[_i];
        deal(underlying, address(this), _amount);
        IERC20(underlying).approve(address(eap), _amount);
        eap.deposit(_amount);

        address[] memory _eaps = new address[](1);
        _eaps[0] = address(eap);
        bytes32[][] memory _configs = new bytes32[][](1);
        bytes32[] memory _configsFirst = new bytes32[](1);
        _configsFirst[0] = _encodeAllocation(_allocation, _amount, false, true);
        _configs[0] = _configsFirst;

        allocator.allocate(_eaps, _configs);

        _advanceTime(7 * 24 * 3600);

        eap.calculateExchangeRate();

        uint256 reserves = eap.reserves();

        console2.log("reserves before withdrawal", reserves);

        eap.requestWithdrawal(_amount, address(this));

        assertEq(eap.balanceOf(address(this)), 0);
        assertEq(eap.balanceOf(address(withdrawTool)), _amount);

        // reallocate #1 to withdraw underlying
        uint256 allocationShares = eap.sharesBalanceOfPool(_allocation);
        _configs[0][0] = _encodeAllocation(_allocation, uint88(allocationShares), true, false);
        allocator.allocate(_eaps, _configs);

        vm.expectRevert(EarlyClaim.selector);
        withdrawTool.claim();

        // reallocate #2 to withdraw underlying
        _configs[0] = new bytes32[](0);
        allocator.allocate(_eaps, _configs);

        uint256 balanceBefore = IERC20(underlying).balanceOf(address(this));
        withdrawTool.claim();
        uint256 balanceAfter = IERC20(underlying).balanceOf(address(this));

        // subtract 1 to overcome precision errors
        assertGe(balanceAfter - balanceBefore, _amount * (1e18 - precisionError) / 1e18);

        int256 earn = int256(balanceAfter - balanceBefore) - int256(int88(_amount));
        console2.log("user earned", earn);

        // sync
        eap.calculateExchangeRate();

        reserves = eap.reserves();
        console2.log("reserves after withdrawal", reserves);
        eap.withdrawReserves(msg.sender);
        assertEq(IERC20(underlying).balanceOf(msg.sender), reserves);

        assertEq(IERC20(underlying).balanceOf(address(eap)), 0);
    }

    event Cancelled(address indexed user, uint256 index, uint256 amount);
    event Fulfilled(uint256 shares, uint256 amount, uint256 index);
    function testRequestTimeLimitWithdrawal(uint88 _amount, uint256 _i) public {
        _amount = uint88(bound(_amount, MIN_TEST_AMOUNT, MAX_TEST_AMOUNT));
        _i = bound(_i, 0, allocations.length - 1);
        console2.log("initial amount", _amount);
        address _allocation = allocations[_i];
        deal(underlying, address(this), _amount);
        IERC20(underlying).approve(address(eap), _amount);
        eap.deposit(_amount);

        address[] memory _eaps = new address[](1);
        _eaps[0] = address(eap);
        bytes32[][] memory _configs = new bytes32[][](1);
        bytes32[] memory _configsFirst = new bytes32[](1);
        _configsFirst[0] = _encodeAllocation(_allocation, _amount, false, true);
        _configs[0] = _configsFirst;

        allocator.allocate(_eaps, _configs);

        _advanceTime(7 * 24 * 3600);

        eap.calculateExchangeRate();

        vm.expectRevert(RequestNotFound.selector);
        withdrawTool.instantWithdrawal();

        eap.requestWithdrawal(_amount, address(this));
        assertEq(eap.balanceOf(address(this)), 0);
        assertEq(eap.balanceOf(address(withdrawTool)), _amount);

        vm.expectRevert(EarlyClaim.selector);
        withdrawTool.instantWithdrawal();

        _advanceTime(withdrawTool.requestTimeLimit() / 2);

        vm.expectRevert(EarlyClaim.selector);
        withdrawTool.instantWithdrawal();

        _advanceTime(withdrawTool.requestTimeLimit() / 2);

        withdrawTool.instantWithdrawal();
        assertEq(eap.balanceOf(address(this)), 0);
        assertGe(IERC20(underlying).balanceOf(address(this)), _amount);

        vm.expectRevert(RequestNotFound.selector);
        withdrawTool.instantWithdrawal();

        /// deposit again
        IERC20(underlying).approve(address(eap), _amount);
        eap.deposit(_amount);

        eap.requestWithdrawal(_amount, address(this));
        assertEq(eap.balanceOf(address(this)), 0);

        // able to cancel requests and withdraw shares
        vm.expectEmit(true, false, false, true);
        emit Cancelled(address(this), 1, _amount);
        withdrawTool.cancelRequest();
        assertEq(eap.balanceOf(address(this)), _amount);

        // request again
        eap.requestWithdrawal(_amount, address(this));

        uint underlyingAmount = withdrawTool.underlyingRequested(address(this));

        // exchange rate should be 1:1 after full withdrawal
        assertEq(underlyingAmount, _amount);

        vm.expectEmit(false, false, false, true);
        emit Fulfilled(0, 0, 1);

        // reallocate #1
        _configs[0][0] = _encodeAllocation(_allocation, uint88(_amount), false, false);
        allocator.allocate(_eaps, _configs);

        // can't cancel after first allocation
        vm.expectRevert(QueuedOrFulfilled.selector);
        withdrawTool.cancelRequest();

        vm.expectEmit(false, false, false, true);
        emit Fulfilled(_amount, underlyingAmount, 2);
        // reallocate #2
        uint256 allocationShares = eap.sharesBalanceOfPool(_allocation);
        _configs[0][0] = _encodeAllocation(_allocation, uint88(allocationShares), true, false);
        allocator.allocate(_eaps, _configs);

        // can't perform an instant withdraw after fulfillment
        vm.expectRevert(AlreadyFulfilled.selector);
        withdrawTool.instantWithdrawal();
    }

    function _encodeAllocation(address _pool, uint88 _amount, bool isRedeem, bool isLast)
        internal
        pure
        returns (bytes32)
    {
        uint8 lastValue = isRedeem ? 0 : 8;
        if (isLast) {
            lastValue += 1;
        }
        bytes memory data = abi.encodePacked(_pool, _amount, lastValue);
        return bytes32(data);
    }

    function _advanceTime(uint256 period) internal virtual {}
}
