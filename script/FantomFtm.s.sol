// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import {TimelockController} from "openzeppelin-contracts/governance/TimelockController.sol";
import {EfficientlyAllocatingPoolEth} from "../src/EfficientlyAllocatingPoolEth.sol";
import {DelayedWithdrawalToolEth} from "../src/DelayedWithdrawalToolEth.sol";
import {Allocator} from "../src/Allocator.sol";
import {EthAdapter} from "../src/EthAdapter.sol";
import "forge-std/Script.sol";

contract FantomFtmScript is Script {
    uint key;

    address govMultisig;

    address underlying;
    address tarotAdapter;
    address allocator;
    address timelock;
    address emergencyTimelock;
    string name;
    string symbol;
    address rewardManager;

    function setUp() public {
        key = vm.envUint("PRIVATE_KEY");
        govMultisig = 0xE568cf78FB55E229dD7197d2c60D8DbB0eC7fe25;
        allocator = 0x3528F60da516c15bEB136b8608D0d61d35E50724;
        tarotAdapter = 0xd56C2CbA8479442f9576897B99b74527626Da409;
        underlying = 0x21be370D5312f44cB42ce377BC9b8a0cEF1A4C83;
        timelock = 0x5C369349D179A8E2e4eb954f3cdD979dC1dF284c;
        emergencyTimelock = 0xF499810944e583909259e8f91a31e596Ab8CCb92;
        name = "Yieldebaran FTM";
        symbol = "yFTM";
        rewardManager = address(0);
    }

    function run() public {
        vm.startBroadcast(key);

        address poolAddress = computeCreateAddress(0x51E93685BC5B645284e39221cEb31c33C647b008, 20);
        address withdrawToolEth = address(new DelayedWithdrawalToolEth(poolAddress, underlying));
        address[] memory allocations = new address[](5);
        uint256 i = 0;
        allocations[i++] = 0x47c7B3f5Fa0d52Dfd51bB04977235adBE32a3002;
        allocations[i++] = 0x0a09C62B10E02882Dea69D84641861292e9ba1d1;
        allocations[i++] = 0x6e11aaD63d11234024eFB6f7Be345d1d5b8a8f38;
        allocations[i++] = 0x06E37d44D85f72FcAb3fE743A129c704D21BAd6f;
        allocations[i++] = 0x0FEeC300a8C3Faee5DE4925BAe909f1E0a87C496;

        i = 0;
        address[] memory platformAdapters = new address[](allocations.length);
        platformAdapters[i++] = address(tarotAdapter);
        platformAdapters[i++] = address(tarotAdapter);
        platformAdapters[i++] = address(tarotAdapter);
        platformAdapters[i++] = address(tarotAdapter);
        platformAdapters[i++] = address(tarotAdapter);

        address eap = address(new EfficientlyAllocatingPoolEth(
            underlying,
            name,
            symbol,
            allocator,
            rewardManager,
            timelock,
            emergencyTimelock,
            withdrawToolEth,
            allocations,
            platformAdapters
        ));
        require(eap == poolAddress);

        new EthAdapter(eap);

        vm.stopBroadcast();
    }
}
