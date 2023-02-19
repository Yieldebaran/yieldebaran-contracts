// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import {IAuth} from "./interfaces/IAuth.sol";
import "./Errors.sol";

contract Auth is IAuth {
    address public override admin = msg.sender;

    address public override reservesManager = msg.sender;
    address public override rewardManager;

    /// @notice it's immutable!
    address public override immutable timeLock;

    /// @notice it's immutable!
    address public override immutable emergencyTimeLock;

    mapping(address => bool) public override allocators;
    mapping(address => bool) public override allowStatus;

    bool public override restrictedPhase = true;

    event AdminSet(address indexed admin);
    event Allowed(address indexed user, bool status);
    event RestrictionPhase(bool status);
    event ReservesManagerSet(address indexed reservesManager);
    event AllocatorSet(address indexed allocator);
    event RewardManagerSet(address indexed rewardManager);
    event AllocatorUnset(address indexed allocator);
    event TimeLockSet(address indexed timeLock);
    event EmergencyTimeLockSet(address indexed emergencyTimeLock);

    modifier onlyAdmin() {
        _restricted(admin);
        _;
    }

    modifier onlyAllocator() {
        if (!allocators[msg.sender]) revert AuthFailed();
        _;
    }

    modifier allowed() {
        if (restrictedPhase && !allowStatus[msg.sender]) revert AuthFailed();
        _;
    }

    modifier onlyTimeLock() {
        _restricted(timeLock);
        _;
    }

    modifier onlyReservesManager() {
        _restricted(reservesManager);
        _;
    }

    modifier onlyRewardManager() {
        _restricted(rewardManager);
        _;
    }

    modifier onlyEmergencyTimeLock() {
        _restricted(emergencyTimeLock);
        _;
    }

    constructor(address _allocator, address _rewardManager, address _timeLock, address _emergencyTimeLock) {
        emit AdminSet(msg.sender);
        emit ReservesManagerSet(msg.sender);
        rewardManager = _rewardManager;
        emit RewardManagerSet(_rewardManager);
        allocators[_allocator] = true;
        allowStatus[msg.sender] = true;
        emit Allowed(msg.sender, true);
        emit RestrictionPhase(true);
        emit AllocatorSet(_allocator);
        timeLock = _timeLock;
        emit TimeLockSet(_timeLock);
        emergencyTimeLock = _emergencyTimeLock;
        emit EmergencyTimeLockSet(_emergencyTimeLock);
    }

    function setAdmin(address _admin) external override onlyAdmin {
        admin = _admin;
        emit AdminSet(_admin);
    }

    function setAllowedToInteract(address _user, bool _status) external override onlyAdmin {
        allowStatus[_user] = _status;
        emit Allowed(_user, _status);
    }

    function setRestrictionPhaseStatus(bool _status) external override onlyAdmin {
        restrictedPhase = _status;
        emit RestrictionPhase(_status);
    }

    function setRewardManager(address _rewardManager) external override onlyAdmin {
        rewardManager = _rewardManager;
        emit RewardManagerSet(_rewardManager);
    }

    function setReservesManager(address _reservesManager) external override onlyAdmin {
        reservesManager = _reservesManager;
        emit ReservesManagerSet(_reservesManager);
    }

    function setAllocator(address _allocator, bool _flag) external override onlyAdmin {
        allocators[_allocator] = _flag;
        if (_flag) {
            emit AllocatorSet(_allocator);
        } else {
            emit AllocatorUnset(_allocator);
        }
    }

    function _restricted(address _allowed) internal view {
        if (msg.sender != _allowed) revert AuthFailed();
    }
}
