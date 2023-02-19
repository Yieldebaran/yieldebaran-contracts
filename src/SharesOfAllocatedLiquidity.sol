// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import {ERC20} from "openzeppelin-contracts/token/ERC20/ERC20.sol";
import {IERC20Metadata} from "openzeppelin-contracts/token/ERC20/extensions/IERC20Metadata.sol";

contract SharesOfAllocatedLiquidity is ERC20 {
    uint8 internal immutable _decimals;

    constructor(address _underlying, string memory _name, string memory _symbol) ERC20(_name, _symbol) {
        _decimals = IERC20Metadata(_underlying).decimals();
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }
}
