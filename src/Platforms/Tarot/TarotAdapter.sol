// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import {IERC20, SafeERC20} from "openzeppelin-contracts/token/ERC20/utils/SafeERC20.sol";
import {IBorrowable} from "./IBorrowable.sol";
import {IPlatformAdapter} from "../IPlatformAdapter.sol";

contract TarotAdapter is IPlatformAdapter {
    using SafeERC20 for IERC20;

    function getUnderlying(address _borrowable) external view override returns (address) {
        return IBorrowable(_borrowable).underlying();
    }

    function getExchangeRate(address _borrowable) internal returns (uint256) {
        uint256 temp = IBorrowable(_borrowable).exchangeRate();
        uint256 exchangeRate = IBorrowable(_borrowable).exchangeRate();
        while (exchangeRate > temp) {
            // ¯\_(ツ)_/¯
            temp = exchangeRate;
            exchangeRate = IBorrowable(_borrowable).exchangeRate();
        }
        return exchangeRate;
    }

    function balance(address _borrowable) public view override returns (uint256) {
        return IBorrowable(_borrowable).balanceOf(address(this));
    }

    function withdraw(address _borrowable, uint256 _amount) external override {
        require(IBorrowable(_borrowable).transfer(_borrowable, _amount), "transfer failed");
        IBorrowable(_borrowable).redeem(address(this));
    }

    function withdrawWithLimit(address _borrowable, uint256 _limit) external override returns (uint256) {
        uint256 sharesBalance = balance(_borrowable);
        if (sharesBalance == 0) return 0;

        // sync `totalBalance`
        IBorrowable(_borrowable).sync();
        uint256 underlyingAvailable = IBorrowable(_borrowable).totalBalance();
        if (underlyingAvailable == 0) return 0;

        uint256 exchangeRate = getExchangeRate(_borrowable);

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

        require(IBorrowable(_borrowable).transfer(_borrowable, sharesToBurn), "transfer failed");

        IBorrowable(_borrowable).redeem(address(this));

        return sharesToBurn * exchangeRate / 1e18;
    }

    function deposit(address _underlying, address _borrowable, uint256 _amount) external override {
        IERC20(_underlying).safeTransfer(_borrowable, _amount);
        IBorrowable(_borrowable).mint(address(this));
    }

    function claimReward(address) external pure override {
        require(false, "No rewards");
    }

    function calculateUnderlyingBalance(address _borrowable) external override returns (uint256) {
        uint256 nativeBalance = balance(_borrowable);
        if (nativeBalance == 0) return 0;
        return nativeBalance * getExchangeRate(_borrowable) / 1e18;
    }
}
