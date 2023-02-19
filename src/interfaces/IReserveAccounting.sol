// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;
interface IReserveAccounting {
    function calculateExchangeRate() external returns (uint256);

    function calculateExchangeRatePayable() external payable returns (uint256);

    function calculateUnderlyingBalance() external returns (uint256);

    function complexityWithdrawalFeeFactor() external view returns (uint256);

    function deposit(uint256 _amount) external;

    function reserves() external view returns (uint256);

    function depositFor(uint256 _amount, address _onBehalfOf) external;

    function instantWithdrawal(
        uint256 _shares,
        uint256 _minFromBalance,
        address _to
    ) external returns (uint256);

    function requestWithdrawal(uint256 _shares, address _to) external;

    function reserveFactor() external view returns (uint256);

    function setComplexityWithdrawalFeeFactor(
        uint256 _complexityWithdrawalFeeFactor
    ) external;

    function setRequestTimeLimit(uint256 _requestTimeLimit) external;

    function setReserveFactor(uint256 _reserveFactor) external;

    function underlyingBalanceStored() external view returns (uint256);

    function underlyingWithFee() external view returns (bool);

    function withdrawReserves(address _to) external;

    function withdrawTool() external view returns (address);
}