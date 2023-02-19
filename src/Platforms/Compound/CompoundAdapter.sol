// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import {IERC20, SafeERC20} from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import {CErc20Interface, CErc20Storage, CTokenInterface} from "./CTokenInterfaces.sol";
import {IPlatformAdapter} from "../IPlatformAdapter.sol";

contract CompoundAdapter is IPlatformAdapter {
    using SafeERC20 for IERC20;

    function withdraw(address _cToken, uint256 _amount) external override {
        require(CErc20Interface(_cToken).redeem(_amount) == 0, "redeem failed");
    }

    // claiming process supposed to go though the RewardManager
    function claimReward(address) external pure override {
        require(false, "No rewards");
    }

    function withdrawWithLimit(address _cToken, uint256 _limit) external override returns (uint256) {
        uint256 sharesBalance = balance(_cToken);
        if (sharesBalance == 0) return 0;

        uint256 underlyingAvailable = CTokenInterface(_cToken).getCash();
        if (underlyingAvailable == 0) return 0;

        uint256 exchangeRate = CTokenInterface(_cToken).exchangeRateCurrent();
        uint256 underlyingBalance = sharesBalance * exchangeRate / 1e18;

        uint256 sharesToBurn;
        if (underlyingBalance > _limit && underlyingAvailable > _limit) {
            sharesToBurn = _limit * 1e18 / exchangeRate + 1;
            if (sharesToBurn * exchangeRate / 1e18 > underlyingAvailable) {
                sharesToBurn -= 1;
            }
        } else {
            uint256 maxWithdrawable = underlyingBalance > underlyingAvailable ? underlyingAvailable : underlyingBalance;
            sharesToBurn = maxWithdrawable * 1e18 / exchangeRate;
        }

        if (sharesToBurn == 0) return 0;

        require(CErc20Interface(_cToken).redeem(sharesToBurn) == 0, "redeem failed");

        return sharesToBurn * exchangeRate / 1e18;
    }

    function deposit(address _underlying, address _cToken, uint256 _amount) external override {
        IERC20(_underlying).safeApprove(_cToken, _amount);
        require(CErc20Interface(_cToken).mint(_amount) == 0, "mint failed");
    }

    function getUnderlying(address _cToken) external view override returns (address) {
        return CErc20Storage(_cToken).underlying();
    }

    function balance(address _cToken) public view override returns (uint256) {
        return CTokenInterface(_cToken).balanceOf(address(this));
    }

    function calculateUnderlyingBalance(address _cToken) external override returns (uint256) {
        uint256 nativeBalance = balance(_cToken);
        if (nativeBalance == 0) return 0;
        return nativeBalance * CTokenInterface(_cToken).exchangeRateCurrent() / 1e18;
    }
}
