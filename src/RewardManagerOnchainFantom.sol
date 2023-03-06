// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import {IEfficientlyAllocatingPool} from "./interfaces/IEfficientlyAllocatingPool.sol";
import {IAllocationConfig} from "./interfaces/IAllocationConfig.sol";
import {CalldataDecoder} from "./CalldataDecoder.sol";
import {ComptrollerInterface} from "./Platforms/Compound/ComptrollerInterface.sol";
import {IERC20, SafeERC20} from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import {Address} from "openzeppelin-contracts/utils/Address.sol";
import "./Errors.sol";

interface ISpookySwap {
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);
}

contract RewardManagerOnchainFantom {
    using SafeERC20 for IERC20;
    using CalldataDecoder for bytes32;
    using Address for address;

    address public constant scream = 0xe0654C8e6fd4D733349ac7E09f6f23DA256bF475;
    address public constant spookyswap = 0xF491e7B69E4244ad4002BC14e878a34207E38c29;
    address public constant screamComptroller = 0x3d3094Aec3b63C744b9fe56397D36bE568faEBdF;
    address public constant wftm = 0x21be370D5312f44cB42ce377BC9b8a0cEF1A4C83;

    address public manager;
    address public owner;

    event ManagerSet(address indexed manager);
    event OwnerSet(address indexed owner);

    modifier auth() {
        if (msg.sender == manager) {
            _;
        } else if (tx.origin == msg.sender && msg.sender.isContract()) {
            // allows tx simulation via `eth_call`
            _;
        } else {
            revert AuthFailed();
        }
    }

    constructor(address _owner, address _manager) {
        IERC20(scream).approve(spookyswap, type(uint256).max);
        IERC20(wftm).approve(spookyswap, type(uint256).max);

        owner = _owner;
        emit OwnerSet(_owner);

        manager = _manager;
        emit ManagerSet(_manager);
    }

    function setManager(address _manager) external {
        if (owner != msg.sender) revert AuthFailed();
        manager = _manager;
        emit ManagerSet(_manager);
    }

    function setOwner(address _owner) external {
        if (owner != msg.sender) revert AuthFailed();
        owner = _owner;
        emit OwnerSet(_owner);
    }

    function _distributeScreamRewards(address _eap, address _cToken) internal returns (uint256) {
        address[] memory holders = new address[](1);
        holders[0] = _eap;
        address[] memory cTokens = new address[](1);
        cTokens[0] = _cToken;

        ComptrollerInterface(screamComptroller).claimComp(holders, cTokens, false, true);
        IEfficientlyAllocatingPool(_eap).pullToken(scream, address(this));

        uint256 screamAmount = IERC20(scream).balanceOf(address(this));

        if (screamAmount == 0) return 0;

        uint256 amount = _swapViaSpookySwap(scream, wftm, screamAmount, address(this));

        address underlying = IAllocationConfig(_eap).underlying();
        if (underlying == wftm) {
            IERC20(wftm).transfer(_eap, amount);
        } else {
            amount = _swapViaSpookySwap(wftm, underlying, amount, _eap);
        }
        return amount;
    }

    function distributeRewards(bytes32[] calldata _claimConfigs) external auth returns (uint256[] memory distributed) {
        distributed = new uint[](_claimConfigs.length);

        for (uint256 i = 0; i < _claimConfigs.length;) {
            (address eap, uint256 minAmount, uint256 index) = _claimConfigs[i].decodeClaim();
            address _allocation = IAllocationConfig(eap).enabledAllocations(index);
            distributed[i] = _distributeScreamRewards(eap, _allocation);
            require(distributed[i] > minAmount, "slippage");
            unchecked {
                ++i;
            }
        }
    }

    function _swapViaSpookySwap(address _assetIn, address _assetOut, uint256 _amountIn, address _to)
        internal
        returns (uint256)
    {
        address[] memory path = new address[](2);
        path[0] = _assetIn;
        path[1] = _assetOut;
        uint256[] memory amounts =
            ISpookySwap(spookyswap).swapExactTokensForTokens(_amountIn, 0, path, _to, type(uint256).max);
        return amounts[amounts.length - 1];
    }
}
