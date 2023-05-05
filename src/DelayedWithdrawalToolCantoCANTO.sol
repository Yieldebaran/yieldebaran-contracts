// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import { EthAdapter } from "./EthAdapter.sol";
import {CSRAssigner} from "./CSRAssigner.sol";
import {DelayedWithdrawalToolEth} from "./DelayedWithdrawalToolEth.sol";

contract DelayedWithdrawalToolCantoCANTO is DelayedWithdrawalToolEth, CSRAssigner {
    constructor(address _pool, address _underlying, uint _tokenId)
    DelayedWithdrawalToolEth(_pool, _underlying)
    CSRAssigner(_tokenId)
    {}
}
