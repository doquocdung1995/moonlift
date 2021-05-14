// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "../interfaces/IUniswapV2Pair.sol";
import "../libs/BEP20.sol";
import "../libs/SafeMath.sol";
import "./PairsHolder.sol";

abstract contract BEP20WithFee is BEP20, PairsHolder {
    using SafeMath for uint256;

    // --==[ FEES ]==--
    // Fees numbers are multiplied by 100
    uint256 public buyFee = 500; // 5%
    uint256 public sellFee = 1000; // 10%

    uint256 public tokenHoldersPart = 5000; // 50%
    uint256 public lpPart = 2500; // 25%
    uint256 public burnPart = 1500; // 15%
    uint256 public projectPart = 1000; // 10%

    // --==[ WALLETS ]==--
    address public projectWallet = 0x10437796b91510e8bB84326fd3b6824de414a313;
    mapping(address => bool) public taxless;

    bool public isFeeActive = true;
    bool public isRewardActive = true;
    uint256 public minTokenBeforeReward = 100e18;

    // --==[ TOTALS ]==--
    uint256 public totalBurnFee;
    uint256 public totalLpFee;
    uint256 public totalProtocolFee;
    uint256 public totalHoldersFee;

    // --==[ Events ]==--
    event LpRewarded(uint256 amount);
    event FeesUpdated(
        uint256 indexed buyFee,
        uint256 indexed sellFee,
        uint256 tokenHoldersPart,
        uint256 lpPart,
        uint256 burnPart,
        uint256 projectPart
    );

    constructor(string memory name, string memory symbol) BEP20(name, symbol) internal {}

    // --==[ External methods ]==--
    function setFees(
        uint256 buyFee_,
        uint256 sellFee_,
        uint256 tokenHoldersPart_,
        uint256 lpPart_,
        uint256 burnPart_,
        uint256 projectPart_
    ) external onlyOwner {
        require(buyFee_ < 10000, "sell fee should be less than 100%");
        require(sellFee_ < 10000, "sell fee should be less than 100%");
        require(tokenHoldersPart_.add(lpPart_).add(burnPart_).add(projectPart_) == 10000,
            "sum of tokenHolders/lp/burn/project parts should be 10000 (100%)");

        buyFee = buyFee_;
        sellFee = sellFee_;
        tokenHoldersPart = tokenHoldersPart_;
        lpPart = lpPart_;
        burnPart = burnPart_;
        projectPart = projectPart_;

        emit FeesUpdated(buyFee, sellFee, tokenHoldersPart, lpPart, burnPart, projectPart);
    }

    function setMinTokenBeforeReward(uint256 amount) external onlyOwner {
        minTokenBeforeReward = amount;
    }

    function setFeeActive(bool value) external onlyOwner {
        isFeeActive = value;
    }

    function setRewardActive(bool value) external onlyOwner {
        isRewardActive = value;
    }

    function setTaxless(address account, bool value) public onlyOwner {
        require(account != address(0), "Taxless is zero-address");
        taxless[account] = value;
    }

    function setProtocolWallet(address account) external onlyOwner {
        require(account != address(0), "Protocol is zero-address");
        projectWallet = account;
    }

    // --==[ Overridden methods ]==--
    function _transfer(address from, address to, uint256 amount) override internal {
        if (!isFeeActive || taxless[from] || taxless[to]) {
            super._transfer(from, to, amount);
            return;
        }

        uint256 holdersFee;
        uint256 lpFee;
        uint256 burnFee;
        uint256 projectFee;
        uint256 lpBalance;

        address lpPair;
        address feePayer;

        if (isPair(from)) {// buying
            (holdersFee, lpFee, burnFee, projectFee) = calcFees(amount.mul(buyFee).div(10000));
            lpBalance = balanceOf(from);
            lpPair = from;
            feePayer = to;
        } else if (isPair(to)) {// selling
            (holdersFee, lpFee, burnFee, projectFee) = calcFees(amount.mul(sellFee).div(10000));
            lpBalance = balanceOf(to);
            lpPair = to;
            feePayer = from;
        }

        // only reward LP when token balance greater then minimum
        if (lpBalance < minTokenBeforeReward) {
            lpFee = 0;
        } else {
            emit LpRewarded(lpFee);
        }

        // increasing total values
        totalHoldersFee = totalHoldersFee.add(holdersFee);
        totalBurnFee = totalBurnFee.add(burnFee);
        totalLpFee = totalLpFee.add(lpFee);
        totalProtocolFee = totalProtocolFee.add(projectFee);

        // in the case of buying we should transfer all amount to buyer and then take fees from it
        if (feePayer == to) {
            super._transfer(from, to, amount);
        }

        if (isRewardActive) {
            // transfer holders fee part
            super._transfer(feePayer, address(this), holdersFee);
            // transfer LP part
            super._transfer(feePayer, lpPair, lpFee);
            // burn the burning fee part
            super._burn(feePayer, burnFee);
            // transfer project fee part
            super._transfer(feePayer, projectWallet, projectFee);
        } else {// if rewards are not active — just burn excess
            super._burn(feePayer, holdersFee.add(lpFee).add(burnFee).add(projectFee));
        }

        // sync pair balance
        if (lpPair != address(0)) {
            IUniswapV2Pair(lpPair).sync();
        }

        // selling? fee is taken from the seller
        if (feePayer == from) {
            amount = amount.sub(holdersFee).sub(burnFee).sub(lpFee).sub(projectFee);
            super._transfer(from, to, amount);
        }
    }

    // --==[ Private methods ]==--
    function calcFees(uint256 amount)
    private view
    returns (uint256 holdersFee, uint256 lpFee, uint256 burnFee, uint256 projectFee)
    {
        // Calc TokenHolders part
        holdersFee = amount.mul(tokenHoldersPart).div(10000);
        lpFee = amount.mul(lpPart).div(10000);
        burnFee = amount.mul(burnPart).div(10000);
        projectFee = amount.mul(projectPart).div(10000);
    }

}
