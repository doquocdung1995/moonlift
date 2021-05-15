// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "./libs/SafeMath.sol";
import "./libs/Ownable.sol";
import "./libs/Address.sol";
import "./abstracts/Governance.sol";
import "./abstracts/BEP20WithFee.sol";
import "./interfaces/IUniswapV2Factory.sol";
import "./interfaces/IUniswapV2Router02.sol";

contract Moonlift is BEP20WithFee("Moonlift", "MLT"), Governance {
    using Address for address;

    constructor(address router, address BUSD) public {
        if (router != address(0)) {
            _createPair(router, IUniswapV2Router02(router).WETH());
            if (BUSD != address(0)) {
                _createPair(router, BUSD);
            }
        }

        // minting 100b to the owner
        setTaxless(_msgSender(), true);
        _mint(_msgSender(), 100_000_000_000e18);
    }

    function _createPair(address router, address token1) private {
        address pair = IUniswapV2Factory(IUniswapV2Router02(router).factory()).createPair(address(this), token1);
        _addPairToTrack(pair);
        rewardsExcluded[pair] = true;
        rewardsExcluded[getPairVault(pair)] = true;
    }

    // --==[ Public functions ]==--
    function addPairToTrack(address pair) external onlyOwner {
        _addPairToTrack(pair);
        rewardsExcluded[pair] = true;
        rewardsExcluded[getPairVault(pair)] = true;
    }

    function burn(uint256 amount) external {
        _burn(_msgSender(), amount);
    }

    function burnFrom(address account, uint256 amount) external {
        uint256 decreasedAllowance = allowance(account, _msgSender()).sub(
            amount, "ERC20: burn amount exceeds allowance"
        );

        _approve(account, _msgSender(), decreasedAllowance);
        _burn(account, amount);
    }

    function _balanceOf(address account) internal override view returns (uint256) {
        return balanceOf(account);
    }

    function _name() internal override view returns (string memory) {
        return name();
    }
}
