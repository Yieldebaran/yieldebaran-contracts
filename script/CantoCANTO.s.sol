// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import {TimelockController} from "openzeppelin-contracts/governance/TimelockController.sol";
import {EfficientlyAllocatingPoolCantoCANTO} from "../src/EfficientlyAllocatingPoolCantoCANTO.sol";
import {DelayedWithdrawalToolCantoCANTO} from "../src/DelayedWithdrawalToolCantoCANTO.sol";
import {Allocator} from "../src/Allocator.sol";
import {CantoAdapter} from "../src/CantoAdapter.sol";
import "forge-std/Script.sol";

interface Turnstile {
    function register(address) external returns(uint256);
}

contract CSRCreator {
    uint public tokenId;

    constructor() {
        //Registers the smart contract with Turnstile
        //Mints the CSR NFT to the contract creator
        tokenId = Turnstile(0xEcf044C5B4b867CFda001101c617eCd347095B44).register(tx.origin);
    }
}

contract CantoCANTOScript is Script {
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
    uint tokenId;

    function setUp() public {
        key = vm.envUint("PRIVATE_KEY");
        govMultisig = 0xE27FBa731e52e29dD414Cd1fbbE72CEF7D5e34be;
        allocator = 0x3528F60da516c15bEB136b8608D0d61d35E50724;
        tarotAdapter = 0x178c6869122EFFF3F147905A5c39F24D0918f084;
        underlying = 0x826551890Dc65655a0Aceca109aB11AbDbD7a07B;
        timelock = 0xF499810944e583909259e8f91a31e596Ab8CCb92;
        emergencyTimelock = 0xd56C2CbA8479442f9576897B99b74527626Da409;
        name = "Yieldebaran CANTO";
        symbol = "yCANTO";
        rewardManager = address(0);
    }

    function run() public {
        vm.startBroadcast(key);

        deployCSR();

        address poolAddress = computeCreateAddress(0x51E93685BC5B645284e39221cEb31c33C647b008, 13 + 3);
        address withdrawToolEth = address(new DelayedWithdrawalToolCantoCANTO(poolAddress, underlying, tokenId));
        address[] memory allocations = new address[](5);
        uint256 i = 0;
        allocations[i++] = 0xA6eA88C4528f2d29BbD7fe803CB3D96946fa7447;
        allocations[i++] = 0x116E3178a857Bc86cACDDDcE854A4662AaE1b133;
        allocations[i++] = 0xe1CC87271c24FED7E2F6f91D929f6969bFA84A16;
        allocations[i++] = 0x41275C2B376a8F304833b428bd51D4B891dC7228;
        allocations[i++] = 0x0Ea0C959aB53D5896dAA77170A55031203e5A0df;

        i = 0;
        address[] memory platformAdapters = new address[](allocations.length);
        platformAdapters[i++] = address(tarotAdapter);
        platformAdapters[i++] = address(tarotAdapter);
        platformAdapters[i++] = address(tarotAdapter);
        platformAdapters[i++] = address(tarotAdapter);
        platformAdapters[i++] = address(tarotAdapter);

        EfficientlyAllocatingPoolCantoCANTO eap = new EfficientlyAllocatingPoolCantoCANTO(
            underlying,
            name,
            symbol,
            allocator,
            rewardManager,
            timelock,
            emergencyTimelock,
            withdrawToolEth,
            allocations,
            platformAdapters,
            tokenId
        );
        require(address(eap) == poolAddress, "address missmatch");

        address ethAdapter = address(new CantoAdapter(address(eap), tokenId));

        eap.setAllowedToInteract(ethAdapter, true);

        vm.stopBroadcast();
    }

    function deployCSR() internal {
        CSRCreator csr = new CSRCreator();
        tokenId = csr.tokenId();
    }
}
