// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "../libs/BEP20.sol";

abstract contract BEP20WithHoldersDistribution is BEP20 {
    mapping(address => bool) public rewardsExcluded;
    mapping(address => uint256) public lastTotalDividends;
    uint256 public rewardsPerHolding;

    constructor(string memory name, string memory symbol)
    BEP20(name, symbol) internal {
        rewardsExcluded[_msgSender()] = true;
    }

    function _calcRewards(address account) internal view virtual returns (uint256) {
        if (account == address(this) || rewardsExcluded[account]) {
            return 0;
        }

        uint256 _balance = super.balanceOf(account);
        uint256 _dividends = super.balanceOf(address(this));

        return (_balance * (_dividends - lastTotalDividends[account])) / totalSupply();
    }

    modifier _distribute(address account) {
        lastTotalDividends[account] = super.balanceOf(address(this));
        uint256 rewards = _calcRewards(account);
        super._transfer(address(this), account, rewards);
        _;
    }

    function excludeFromRewards(address account) _distribute(account) public onlyOwner {
        rewardsExcluded[account] = true;
    }

    function includeInRewards(address account) _distribute(account) public onlyOwner {
        delete rewardsExcluded[account];
    }

    function addRewards(address from, uint256 amount) internal {
        BEP20._transfer(from, address(this), amount);
    }

    /**
     * @dev See {BEP20-balanceOf}.
     */
    function balanceOf(address account) public view virtual override returns (uint256) {
        return super.balanceOf(account) + _calcRewards(account);
    }
}
