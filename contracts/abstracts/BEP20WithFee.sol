// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "../interfaces/IUniswapV2Pair.sol";
import "../interfaces/IUniswapV2Router02.sol";
import "../libs/SafeMath.sol";
import "./PairsHolder.sol";
import "./BEP20WithHoldersDistribution.sol";

abstract contract BEP20WithFee is BEP20WithHoldersDistribution, PairsHolder {
    using SafeMath for uint256;

    // --==[ FEES ]==--
    // Fees numbers are multiplied by 100
    uint256 public buyFee = 500; // 5%
    uint256 public sellFee = 1000; // 10%

    uint256 public tokenHoldersPart = 5000; // 50%
    uint256 public lpPart = 2500; // 25%
    uint256 public burnPart = 1500; // 15%
    uint256 public projectPart = 1000; // 10%

    uint256 private minLPBalance = 1e18;

    // --==[ WALLETS ]==--
    address public teamWallet;
    mapping(address => bool) public taxless;

    bool public isFeeActive = true;
    bool public isRewardActive = true;
    uint256 public minTokenBeforeReward = 100e18;

    // --==[ TOTALS ]==--
    uint256 public totalBurnFee;
    uint256 public totalLpFee;
    uint256 public totalProtocolFee;
    uint256 public totalHoldersFee;

    address internal wBNB;
    address internal router;

    // --==[ Events ]==--
    event LpRewarded(address indexed lpPair, uint256 amount);
    event FeesUpdated(
        uint256 indexed buyFee,
        uint256 indexed sellFee,
        uint256 tokenHoldersPart,
        uint256 lpPart,
        uint256 burnPart,
        uint256 projectPart
    );

    constructor(string memory name, string memory symbol)
    BEP20WithHoldersDistribution(name, symbol) internal {
        teamWallet = _msgSender();
    }

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

    function setTeamWallet(address account) external onlyOwner {
        require(account != address(0), "Team wallet is zero-address");
        require(teamWallet != account, "Team wallet is the same");

        // include old project wallet to rewards
        if (teamWallet != address(0)) {
            setTaxless(teamWallet, false);
            includeInRewards(teamWallet);
        }
        teamWallet = account;

        // exclude new project wallet to rewards
        if (teamWallet != address(0)) {
            setTaxless(teamWallet, true);
            excludeFromRewards(teamWallet);
        }
    }

    // --==[ Overridden methods ]==--
    function _transfer(address from, address to, uint256 amount) override
    _distribute(from) internal {
        checkAndLiquify(from, to);

        if ((!isPair(from) && !isPair(to)) || !isFeeActive ||
        taxless[from] || taxless[to] || taxless[msg.sender] || taxless[tx.origin]) {
            super._transfer(from, to, amount);
            return;
        }

        uint256 holdersFee;
        uint256 lpFee;
        uint256 burnFee;
        uint256 projectFee;

        address lpPair;
        address feePayer;

        if (from == msg.sender && isPair(from)) {// buying
            (holdersFee, lpFee, burnFee, projectFee) = calcFees(amount.mul(buyFee).div(10000));
            lpPair = from;
            feePayer = to;
        } else if (isPair(to)) {// selling
            (holdersFee, lpFee, burnFee, projectFee) = calcFees(amount.mul(sellFee).div(10000));
            lpPair = to;
            feePayer = from;
        }

        // only reward LP when token balance greater then minimum
        if (lpPair != address(0)) {
            if (balanceOf(lpPair) < minTokenBeforeReward) {
                lpFee = 0;
            } else {
                emit LpRewarded(lpPair, lpFee);
            }
        }
        {
            // increasing total values
            totalHoldersFee = totalHoldersFee.add(holdersFee);
            totalBurnFee = totalBurnFee.add(burnFee);
            totalLpFee = totalLpFee.add(lpFee);
            totalProtocolFee = totalProtocolFee.add(projectFee);
        }

        _processPayment(from, to, amount, holdersFee, lpFee, burnFee, projectFee, lpPair, feePayer);
    }

    function _processPayment(
        address from, address to, uint256 amount,
        uint256 holdersFee, uint256 lpFee, uint256 burnFee,
        uint256 projectFee, address lpPair, address feePayer
    ) private {
        // in the case of buying we should transfer all amount to buyer and then take fees from it
        if (feePayer == to) {
            super._transfer(from, to, amount);
        }

        if (isRewardActive) {
            // transfer holders fee part
            addRewards(feePayer, holdersFee);
            // transfer LP part
            super._transfer(feePayer, pair_vaults[lpPair], lpFee);
            // burn the burning fee part
            super._burn(feePayer, burnFee);
            // transfer project fee part
            super._transfer(feePayer, teamWallet, projectFee);
        } else {// if rewards are not active — just burn excess
            super._burn(feePayer, holdersFee.add(lpFee).add(burnFee).add(projectFee));
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

    function checkAndLiquify(address from, address to) private lock {
        uint256 pairs_length = pairsLength();

        // this loop is safe because pairs length would never been more than 25
        for (uint256 idx = 0; idx < pairs_length; idx++) {
            address pair = pairs[idx];
            address vault = getPairVault(pair);
            uint256 lpVaultBalance = BEP20.balanceOf(vault);

            bool overMinTokenBalance = lpVaultBalance >= minLPBalance;
            if (
                overMinTokenBalance &&
                from != pair && // couldn't liquify if sender or receiver is the same pair!
                to != pair // couldn't liquify if sender or receiver is the same pair!
            ) {
                BEP20._transfer(vault, pair, lpVaultBalance);
                IUniswapV2Pair(pair).sync();
            }
        }
    }

    bool private locked;
    modifier lock {
        require(!locked, "Locked");
        locked = true;
        _;
        locked = false;
    }
}
