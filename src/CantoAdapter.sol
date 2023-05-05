// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import { EthAdapter } from "./EthAdapter.sol";
import {CSRAssigner} from "./CSRAssigner.sol";

contract CantoAdapter is EthAdapter, CSRAssigner {
    constructor(address _eap, uint _tokenId) EthAdapter(_eap) CSRAssigner(_tokenId) {}
}
