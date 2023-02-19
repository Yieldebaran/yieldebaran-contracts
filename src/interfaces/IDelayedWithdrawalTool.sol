// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;
interface IDelayedWithdrawalTool {
    function cancelRequest() external;

    function claim() external;

    function claimFor(address _account) external;

    function claimTo(address _onBehalfOf) external;

    function fulfillmentIndex() external view returns (uint256);

    function getAmountsToFulfill()
    external
    view
    returns (uint256 sharesAmount, uint256 underlyingAmount);

    function instantWithdrawal() external;

    function instantWithdrawalFor(address _account) external;

    function instantWithdrawalTo(address _onBehalfOf) external;

    function isRequested() external view returns (bool);

    function markFulfilled() external;

    function pool() external view returns (address);

    function request(
        address _account,
        uint256 _shares,
        uint256 _amount
    ) external;

    function requestIndex(address) external view returns (uint256);

    function requestTime(address) external view returns (uint256);

    function requestTimeLimit() external view returns (uint256);

    function setRequestTimeLimit(uint256 _requestTimeLimit) external;

    function sharesRequested(address) external view returns (uint256);

    function totalSharesRequested(uint256) external view returns (uint256);

    function totalUnderlyingRequested(uint256) external view returns (uint256);

    function underlying() external view returns (address);

    function underlyingRequested(address) external view returns (uint256);
}