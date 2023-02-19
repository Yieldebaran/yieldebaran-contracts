// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;
interface IEffectivelyAllocatingPool {
    function admin() external view returns (address);

    function allocate(bytes32[] memory _allocationConfigs) external;

    function allocators(address) external view returns (bool);

    function allowStatus(address) external view returns (bool);

    function allowance(address owner, address spender)
    external
    view
    returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function balanceOf(address account) external view returns (uint256);

    function calculateExchangeRate() external returns (uint256);

    function calculateExchangeRatePayable() external payable returns (uint256);

    function calculateUnderlyingBalance() external returns (uint256);

    function claimRewards(address _allocation) external;

    function complexityWithdrawalFeeFactor() external view returns (uint256);

    function decimals() external view returns (uint8);

    function decreaseAllowance(address spender, uint256 subtractedValue)
    external
    returns (bool);

    function deposit(uint256 _amount) external;

    function depositFor(uint256 _amount, address _onBehalfOf) external;

    function disableAllocation(address _allocation) external;

    function doSomething(address[] memory callees, bytes[] memory data)
    external;

    function emergencyTimeLock() external view returns (address);

    function enableAllocation(address _allocation, address _platformAdapter)
    external;

    function enabledAllocations(uint256) external view returns (address);

    function getAllocations() external view returns (address[] memory);

    function increaseAllowance(address spender, uint256 addedValue)
    external
    returns (bool);

    function instantWithdrawal(
        uint256 _shares,
        uint256 _minFromBalance,
        address _to
    ) external returns (uint256);

    function name() external view returns (string memory);

    function platformAdapter(address) external view returns (address);

    function pullToken(address _token, address _to)
    external
    returns (uint256 amountPulled);

    function requestWithdrawal(uint256 _shares, address _to) external;

    function reserveFactor() external view returns (uint256);

    function reserves() external view returns (uint256);

    function reservesManager() external view returns (address);

    function restrictedPhase() external view returns (bool);

    function rewardManager() external view returns (address);

    function setAdmin(address _admin) external;

    function setAllocator(address _allocator, bool _flag) external;

    function setAllowedToInteract(address _user, bool _status) external;

    function setComplexityWithdrawalFeeFactor(
        uint256 _complexityWithdrawalFeeFactor
    ) external;

    function setRequestTimeLimit(uint256 _requestTimeLimit) external;

    function setReserveFactor(uint256 _reserveFactor) external;

    function setReservesManager(address _reservesManager) external;

    function setRestrictionPhaseStatus(bool _status) external;

    function setRewardManager(address _rewardManager) external;

    function sharesBalanceOfPool(address _allocation)
    external
    returns (uint256);

    function symbol() external view returns (string memory);

    function timeLock() external view returns (address);

    function totalSupply() external view returns (uint256);

    function transfer(address to, uint256 amount) external returns (bool);

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);

    function underlying() external view returns (address);

    function underlyingBalanceStored() external view returns (uint256);

    function underlyingWithFee() external view returns (bool);

    function withdrawReserves(address _to) external;

    function withdrawTool() external view returns (address);
}