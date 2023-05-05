// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

interface Turnstile { function assign(uint256) external returns(uint256); }

contract CSRAssigner {
    constructor(uint tokenId) { Turnstile(0xEcf044C5B4b867CFda001101c617eCd347095B44).assign(tokenId); }
}
