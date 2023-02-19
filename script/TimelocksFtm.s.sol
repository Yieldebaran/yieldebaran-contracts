// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import {TimelockController} from "openzeppelin-contracts/governance/TimelockController.sol";
import "forge-std/Script.sol";

contract TimelocksDeployScript is Script {

    uint key;

    address govMultisig;

    function setUp() public {
        key = vm.envUint("PRIVATE_KEY");
        govMultisig = 0xE568cf78FB55E229dD7197d2c60D8DbB0eC7fe25;
    }

    function run() public {
        uint minDelay = 2 days;
        address[] memory admins = new address[](1);
        admins[0] = govMultisig;
        vm.startBroadcast(key);
        new TimelockController(minDelay, admins, admins, govMultisig);
        new TimelockController(minDelay, admins, admins, govMultisig);
        vm.stopBroadcast();
    }
}
