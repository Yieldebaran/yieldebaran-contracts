// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;
interface IAuth {
    function admin() external view returns (address);

    function allocators(address) external view returns (bool);

    function allowStatus(address) external view returns (bool);

    function emergencyTimeLock() external view returns (address);

    function reservesManager() external view returns (address);

    function restrictedPhase() external view returns (bool);

    function rewardManager() external view returns (address);

    function setAdmin(address _admin) external;

    function setAllocator(address _allocator, bool _flag) external;

    function setAllowedToInteract(address _user, bool _status) external;

    function setReservesManager(address _reservesManager) external;

    function setRestrictionPhaseStatus(bool _status) external;

    function setRewardManager(address _rewardManager) external;

    function timeLock() external view returns (address);
}