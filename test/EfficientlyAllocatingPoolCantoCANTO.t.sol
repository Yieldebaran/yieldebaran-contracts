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
import {DelayedWithdrawalToolEth} from "../src/DelayedWithdrawalToolEth.sol";
import {DelayedWithdrawalTool} from "../src/DelayedWithdrawalTool.sol";
import {Allocator} from "../src/Allocator.sol";
import {EfficientlyAllocatingPoolCantoTest} from "./EfficientlyAllocatingPoolCanto.t.sol";
import {EfficientlyAllocatingPoolEth} from "../src/EfficientlyAllocatingPoolEth.sol";
import {EthAdapter} from "../src/EthAdapter.sol";
import {Address} from "openzeppelin-contracts/utils/Address.sol";
import {TarotAdapter} from "../src/Platforms/Tarot/TarotAdapter.sol";
import "../src/Errors.sol";

contract EfficientlyAllocatingPoolCantoCANTOTest is EfficientlyAllocatingPoolCantoTest {
    EfficientlyAllocatingPoolEth public eapEth;
    EthAdapter public ethAdapter;
    DelayedWithdrawalToolEth public withdrawToolEth;

    receive() external payable {
        if (msg.sender != underlying) revert AuthFailed();
    }

    function setUp() public {
        MIN_TEST_AMOUNT = 0.01e18;
        MAX_TEST_AMOUNT = 1_000e18;

        uint256 fork = vm.createFork(rpcUrl);
        vm.selectFork(fork);

        vm.rollFork(4037852);

//        deployedContracts++;

        underlying = 0x826551890Dc65655a0Aceca109aB11AbDbD7a07B;
        precisionError = 10 ** (18 - IERC20Metadata(underlying).decimals());
        string memory _name = "Yieldebaran CANTO";
        string memory _symbol = "yCANTO";
        allocator = new Allocator(address(this));
        deployedContracts++;

        tarotAdapter = address(new TarotAdapter());
        deployedContracts++;

        address _timeLock = address(this);
        address _emergencyTimeLock = address(this);
        address poolAddress = computeCreateAddress(address(this), deployedContracts + 2);
        withdrawToolEth = new DelayedWithdrawalToolEth(poolAddress, underlying);
        withdrawTool = DelayedWithdrawalTool(address(withdrawToolEth));
        deployedContracts++;
        address[] memory _allocations = new address[](5);
        uint256 i = 0;
        _allocations[i++] = 0xA6eA88C4528f2d29BbD7fe803CB3D96946fa7447;
        _allocations[i++] = 0x116E3178a857Bc86cACDDDcE854A4662AaE1b133;
        _allocations[i++] = 0xe1CC87271c24FED7E2F6f91D929f6969bFA84A16;
        _allocations[i++] = 0x41275C2B376a8F304833b428bd51D4B891dC7228;
        _allocations[i++] = 0x0Ea0C959aB53D5896dAA77170A55031203e5A0df;

        i = 0;
        address[] memory _platformAdapters = new address[](_allocations.length);
        for (uint j = 0; j < _allocations.length; j++) {
            _platformAdapters[j] = address(tarotAdapter);
        }

        platformAdapters = _platformAdapters;
        allocations = _allocations;

        eapEth = new EfficientlyAllocatingPoolEth(
            underlying,
            _name,
            _symbol,
            address(allocator),
            address(address(this)),
            _timeLock,
            _emergencyTimeLock,
            address(withdrawTool),
            _allocations,
            _platformAdapters
        );
        deployedContracts++;

        eap = EfficientlyAllocatingPool(address(eapEth));

        ethAdapter = new EthAdapter(address(eapEth));
        deployedContracts++;
        assertEq(poolAddress, address(eap));
        eap.setRestrictionPhaseStatus(false);
        console2.log("deployed");
    }

    function testDepositEth(address _from, uint256 _amount) public {
        vm.assume(_from != address(0) && !Address.isContract(_from));
        _amount = uint88(bound(_amount, MIN_TEST_AMOUNT, MAX_TEST_AMOUNT));

        vm.expectEmit(true, true, false, true);
        emit Deposit(address(ethAdapter), _from, _amount, _amount);
        hoax(_from, _amount);
        uint256 balanceBefore = _from.balance;
        ethAdapter.depositEth{value: _amount}();
        assertEq(eap.balanceOf(_from), _amount);
        assertEq(IERC20(underlying).balanceOf(address(eap)), _amount);
        assertEq(balanceBefore - _from.balance, _amount);
    }

    function testDepositEthFor(address _from, uint256 _amount) public {
        vm.assume(_from != address(0) && !Address.isContract(_from));
        _amount = uint88(bound(_amount, MIN_TEST_AMOUNT, MAX_TEST_AMOUNT));

        vm.expectEmit(true, true, false, true);
        emit Deposit(address(ethAdapter), address(this), _amount, _amount);
        hoax(_from, _amount);
        ethAdapter.depositEthFor{value: _amount}(address(this));
        assertEq(eap.balanceOf(_from), 0);
        assertEq(eap.balanceOf(address(this)), _amount);
        assertEq(IERC20(underlying).balanceOf(address(eap)), _amount);
    }

    function testInstantWithdrawalEth(uint88 _amount, uint256 _i) public {
        _amount = uint88(bound(_amount, MIN_TEST_AMOUNT, MAX_TEST_AMOUNT));
        _i = bound(_i, 0, allocations.length - 1);
        console2.log("initial amount", _amount);
        address _allocation = allocations[_i];
        deal(address(this), _amount);
//        IERC20(underlying).approve(address(eap), _amount);
        ethAdapter.depositEth{value: _amount}();
        assertEq(eap.balanceOf(address(this)), _amount);

        address[] memory _pools = new address[](1);
        _pools[0] = address(eap);
        bytes32[][] memory _configs = new bytes32[][](1);
        bytes32[] memory _configsFirst = new bytes32[](1);
        _configsFirst[0] = _encodeAllocation(_allocation, _amount, false, true);
        _configs[0] = _configsFirst;

        allocator.allocate(_pools, _configs);

        _advanceTime(24 * 3600);

        address to = address(1234928942);

        uint256 exchangeRate = eap.calculateExchangeRate();
        uint256 expectedReturn = _amount * exchangeRate / 1e18;

        expectedReturn = expectedReturn * (1e18 - eap.complexityWithdrawalFeeFactor()) / 1e18;

        vm.expectEmit(true, true, false, true);
        emit InstantWithdrawal(address(this), to, _amount, expectedReturn);

        uint256 balanceBefore = to.balance;
        eapEth.instantWithdrawalEth(_amount, 0, to);
//        assertGe(expectedReturn, _amount * (1e18 - eap.complexityWithdrawalFeeFactor()) / 1e18);
        assertEq(to.balance - balanceBefore, expectedReturn);
    }

    event Requested(address indexed user, uint256 index, uint256 shares, uint256 amount);
    event AllocatorSet(address indexed allocator);
    event AllocatorUnset(address indexed allocator);

    function testDelayedWithdrawalEth(uint88 _amount) public {
        _amount = uint88(bound(_amount, MIN_TEST_AMOUNT, MAX_TEST_AMOUNT));
        assertEq(withdrawToolEth.isRequested(), false);

        deal(address(this), _amount);
        IERC20(underlying).approve(address(eap), _amount);
        ethAdapter.depositEth{value: _amount}();

        vm.expectEmit(true, false, false, true, address(withdrawToolEth));
        emit Requested(address(this), 1, _amount, _amount);
        eapEth.requestWithdrawal(_amount, address(this));

        assertEq(withdrawToolEth.isRequested(), true);

        vm.expectEmit(true, true, false, false);
        emit AllocatorUnset(address(allocator));
        eap.setAllocator(address(allocator), false);

        // disabled allocator unable to perform allocation
        address[] memory pools = new address[](1);
        pools[0] = address(eap);
        bytes32[][] memory cfgs = new bytes32[][](1);
        bytes32[] memory emptyConf = new bytes32[](1);
        emptyConf[0] = bytes32(0);
        cfgs[0] = emptyConf;
        vm.expectRevert(AuthFailed.selector);
        allocator.allocate(pools, cfgs);

        // disallowed allocator unable to perform allocation
        bytes32[] memory configs;
        vm.expectRevert(AuthFailed.selector);
        eap.allocate(configs);

        // enable allocator
        vm.expectEmit(true, false, false, false);
        emit AllocatorSet(address(this));
        eap.setAllocator(address(this), true);

        // first allocation
        vm.expectEmit(false, false, false, true, address(withdrawToolEth));
        emit Fulfilled(0, 0, 1);
        eap.allocate(configs);

        // revert cancellation after fulfillment
        vm.expectRevert(QueuedOrFulfilled.selector);
        withdrawToolEth.cancelRequest();

        // perform request fulfillment through the empty allocation
        vm.expectEmit(false, false, false, true, address(withdrawToolEth));
        emit Fulfilled(uint256(_amount), uint256(_amount), 2);
        eap.allocate(configs);

        // revert cancellation after fulfillment
        vm.expectRevert(QueuedOrFulfilled.selector);
        withdrawToolEth.cancelRequest();

        uint256 bobBalancePrev = bob.balance;
        withdrawToolEth.claimEthTo(bob);
        assertEq(bob.balance - bobBalancePrev, _amount);

        // revert double claim
        vm.expectRevert(RequestNotFound.selector);
        withdrawToolEth.claimEthTo(bob);
    }

    function testRequestTimeLimitEthWithdrawal(uint88 _amount, uint256 _i) public {
        _amount = uint88(bound(_amount, MIN_TEST_AMOUNT, MAX_TEST_AMOUNT));
        _i = bound(_i, 0, allocations.length - 1);
        console2.log("initial amount", _amount);
        address _allocation = allocations[_i];
        deal(address(this), _amount);
        ethAdapter.depositEth{value: _amount}();

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
        withdrawToolEth.instantWithdrawalEth();

        eap.requestWithdrawal(_amount, address(this));
        assertEq(eap.balanceOf(address(this)), 0);
        assertEq(eap.balanceOf(address(withdrawTool)), _amount);

        vm.expectRevert(EarlyClaim.selector);
        withdrawToolEth.instantWithdrawalEth();

        _advanceTime(withdrawTool.requestTimeLimit() / 2);

        vm.expectRevert(EarlyClaim.selector);
        withdrawToolEth.instantWithdrawalEth();

        _advanceTime(withdrawTool.requestTimeLimit() / 2);

        uint rate = eap.calculateExchangeRate();
        uint bobBalanceBefore = bob.balance;
        withdrawToolEth.instantWithdrawalEthTo(bob);
        assertEq(eap.balanceOf(address(this)), 0);

        assertGe(bob.balance - bobBalanceBefore, _amount * rate / 1e18);

        vm.expectRevert(RequestNotFound.selector);
        withdrawToolEth.instantWithdrawalEth();

        /// deposit again
        deal(address(this), _amount);
        ethAdapter.depositEth{value: _amount}();

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

        // can't perform an instant withdraw after the fulfillment
        vm.expectRevert(AlreadyFulfilled.selector);
        withdrawToolEth.instantWithdrawalEth();
    }
}
