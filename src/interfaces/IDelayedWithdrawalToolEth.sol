// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;
interface IDelayedWithdrawalToolEth {
    function claimEth() external;

    function claimEthFor(address _onBehalfOf) external;

    function claimEthTo(address _onBehalfOf) external;

    function instantWithdrawalEth() external;

    function instantWithdrawalEthFor(address _account) external;

    function instantWithdrawalEthTo(address _onBehalfOf) external;
}