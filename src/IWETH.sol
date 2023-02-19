// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

interface IWETH {
    function withdraw(uint256 wad) external;
    function deposit() external payable;
    function approve(address guy, uint256 wad) external returns (bool);
}
