// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "forge-std/Script.sol";
import {TarotAdapter} from "../src/Platforms/Tarot/TarotAdapter.sol";

contract TarotAdapterDeployScript is Script {

    uint key;

    function setUp() public {
        key = vm.envUint("PRIVATE_KEY");
    }

    function run() public {
        vm.startBroadcast(key);
        new TarotAdapter();
        vm.stopBroadcast();
    }
}
