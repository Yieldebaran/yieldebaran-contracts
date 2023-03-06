// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import {IEfficientlyAllocatingPool} from "./interfaces/IEfficientlyAllocatingPool.sol";
import {ComptrollerInterface} from "./Platforms/Compound/ComptrollerInterface.sol";
import {IERC20} from "openzeppelin-contracts/token/ERC20/IERC20.sol";
import {RewardManagerOnchainFantom} from "./RewardManagerOnchainFantom.sol";
import "./Errors.sol";

contract RewardManager1inchFantom is RewardManagerOnchainFantom {
    address public constant inchRouter = 0x1111111254EEB25477B68fb85Ed929f73A960582;

    constructor(address _owner, address _manager) RewardManagerOnchainFantom(_owner, _manager) {
        IERC20(scream).approve(inchRouter, type(uint256).max);
    }

    function distributeScream(address _eap, address _cToken, bytes calldata _swapData) external auth {
        if (_eap != address(0)) {
            claimScream(_eap, _cToken);
        }
        (bool callResult,) = inchRouter.call(_swapData);
        require(callResult, "1inch call failed");
    }

    function claimScream(address _eap, address _cToken) public {
        address[] memory holders = new address[](1);
        holders[0] = _eap;
        address[] memory cTokens = new address[](1);
        cTokens[0] = _cToken;
        ComptrollerInterface(screamComptroller).claimComp(holders, cTokens, false, true);
        IEfficientlyAllocatingPool(_eap).pullToken(scream, address(this));
    }
}
