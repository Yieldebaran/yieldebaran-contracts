// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import {IWETH} from "./IWETH.sol";
import {IReserveAccounting} from "./interfaces/IReserveAccounting.sol";
import {IAuth} from "./interfaces/IAuth.sol";
import {IAllocationConfig} from "./interfaces/IAllocationConfig.sol";
import "./Errors.sol";

contract EthAdapter {
    address public immutable eap;
    address public immutable underlying;

    constructor(address _eap) {
        eap = _eap;
        address _underlying = IAllocationConfig(eap).underlying();

        // approve forever
        IWETH(_underlying).approve(_eap, type(uint256).max);
        underlying = _underlying;
    }

    function depositEth() external payable {
        depositEthFor(msg.sender);
    }

    function depositEthFor(address _onBehalfOf) public payable {
        if (IAuth(eap).restrictedPhase() && !IAuth(eap).allowStatus(msg.sender))
            revert AuthFailed();
        uint256 amount = msg.value;

        // wrap Eth
        IWETH(underlying).deposit{value: amount}();

        IReserveAccounting(eap).depositFor(amount, _onBehalfOf);
    }
}
