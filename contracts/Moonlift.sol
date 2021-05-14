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

    address public _chef;

    event ChefChanged(address newChef);

    modifier onlyChef() {
        require(_msgSender() == _chef, "not a chef");
        _;
    }

    constructor(address router) public {
        if (router != address(0)) {
            IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(router);

            // Create a uniswap pair for this new token
            address uniswapV2Pair = IUniswapV2Factory(
                _uniswapV2Router.factory()
            ).createPair(address(this), _uniswapV2Router.WETH());

            // Adding new pair to track
            _addPairToTrack(uniswapV2Pair);
        }

        // no taxes from owner
        setTaxless(_msgSender(), true);

        // minting 100kkk to the owner
        _mint(_msgSender(), 100_000_000_000e18);
    }

    // --==[ Public functions ]==--
    function addPairToTrack(address pair) external onlyOwner {
        _addPairToTrack(pair);
    }

    function setChef(address chef_) external onlyOwner {
        require(chef_ != address(0), "Chef is zero-address");
        _chef = chef_;
        emit ChefChanged(chef_);
    }

    /// @notice Creates `_amount` token to `_to`. Must only be called by the owner (MasterChef).
    function mint(address _to, uint256 _amount) external onlyChef {
        _mint(_to, _amount);
        _moveDelegates(address(0), _delegates[_to], _amount);
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

    function _balanceOf(address account) internal override view returns(uint256) {
        return balanceOf(account);
    }

    function _name() internal override view returns (string memory) {
        return name();
    }
}

