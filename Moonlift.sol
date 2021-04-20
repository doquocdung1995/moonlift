// SPDX-License-Identifier: MIT

import "./libs/SafeMath.sol";
import "./libs/IBEP20.sol";
import "./libs/Ownable.sol";
import "./libs/BEP20.sol";

pragma solidity >=0.6.0 <0.8.0;
 
 
interface IUniswapV2Factory {
    function createPair(address tokenA, address tokenB) external returns (address pair);
}

interface IUniswapV2Pair {
    function sync() external;
}

interface IUniswapV2Router01 {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);
}

interface IUniswapV2Router02 is IUniswapV2Router01 {
    function removeLiquidityETHSupportingFeeOnTransferTokens(
      address token,
      uint liquidity,
      uint amountTokenMin,
      uint amountETHMin,
      address to,
      uint deadline
    ) external returns (uint amountETH);
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable;
}

contract LpWallet {
    constructor() public {
    }
}
 

contract Moonlift is BEP20('Moonlift', 'MLT') {
    //all fees are 2 decimals
    uint256 public projectWalletFee = 250; // 2.5%
    uint256 public adminWalletFee = 50; // 0.5%
    uint256 public liquidityFee = 125; // 1.25%
    uint256 public burnFee = 75; // 0.75%
    
    address public lpWallet;
    address public adminWallet = 0x3596274E64CE35299Ad9e21bb646395B793ab7fC;
    address public projectWallet = 0x10437796b91510e8bB84326fd3b6824de414a313;
    
    bool public isTaxActive = true;
    bool public isRewardActive = true;
    uint256 public minTokenBeforeReward = 100e18;
    
    mapping(address=>bool) public taxless;
    address public  uniswapV2Pair;
    uint256 public sellPenaltyMultiplier = 2;

    uint256 public totalBurnFee;
    uint256 public totalLpFee;
    uint256 public totalProcotolFee;
    uint256 public totalAdminFee;

    event LpRewarded(uint256 amount);
   
    constructor() public {
        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(0x05fF2B0DB69458A0750badebc4f9e13aDd608C7F);
        // IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
         // Create a uniswap pair for this new token
        uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory())
            .createPair(address(this), _uniswapV2Router.WETH());
        
        lpWallet = address(new LpWallet());
        taxless[_msgSender()] = true;
        _mint(msg.sender,100_000_000_000e18);
    }
    
    function setRewardActive(bool value) public onlyOwner {
        isRewardActive = value;
    }
    
    function setSellPenalty(uint256 value) public onlyOwner {
        sellPenaltyMultiplier = value;
    }
    
    function setMinTokenBeforeReward(uint256 amount) public onlyOwner {
        minTokenBeforeReward = amount;
    }
    
    function setTaxActive(bool value) public onlyOwner {
        isTaxActive = value;
    }
    
    function setPair(address pair) public onlyOwner {
        uniswapV2Pair = pair;
    }
    
    function setTaxless(address account, bool value) public onlyOwner {
        taxless[account] = value;
    }
    
    function setAdminWallet(address account) public onlyOwner {
        adminWallet = account;
    }
    
    function setProtocolWallet(address account) public onlyOwner {
        projectWallet = account;
    }
   
    function updateFee(uint256 _burnFee, uint256 _lpFee, uint256 _admiFee, uint256 _projectFee) public onlyOwner {
        burnFee = _burnFee;
        liquidityFee = _lpFee;
        adminWalletFee = _admiFee;
        projectWalletFee = _projectFee;
    }
    
    /// @notice Creates `_amount` token to `_to`. Must only be called by the owner (MasterChef).
    function mint(address _to, uint256 _amount) public onlyOwner {
        _mint(_to, _amount);
        _moveDelegates(address(0), _delegates[_to], _amount);
    }

    function burn(uint256 amount) public {
         _burn(_msgSender(), amount);
    }

    function burnFrom(address account, uint256 amount) public {
        uint256 decreasedAllowance = allowance(account, _msgSender()).sub(amount, "ERC20: burn amount exceeds allowance");

        _approve(account, _msgSender(), decreasedAllowance);
        _burn(account, amount);
    }
    
    function rewardLiquidityProviders() private {
        uint256 tokenBalance = balanceOf(lpWallet);
        if(tokenBalance > minTokenBeforeReward) {
            _transfer(lpWallet,uniswapV2Pair,tokenBalance);
            IUniswapV2Pair(uniswapV2Pair).sync();
        }
    }

    function transferWithFee(address sender, address recipient, uint256 amount) private {
        if(isRewardActive && sender != uniswapV2Pair)
            rewardLiquidityProviders();
        
        uint256 _burnFee = amount.mul(burnFee).div(10000);
        uint256 _lpFee = amount.mul(liquidityFee).div(10000);
        uint256 _adminFee = amount.mul(adminWalletFee).div(10000);
        uint256 _projectFee = amount.mul(projectWalletFee).div(10000);
        
        // if sell side, charge 2x fee
        if(recipient == uniswapV2Pair)  {
            _burnFee = _burnFee.mul(sellPenaltyMultiplier);
            _lpFee = _lpFee.mul(sellPenaltyMultiplier);
            _adminFee = _adminFee.mul(sellPenaltyMultiplier);
            _projectFee = _projectFee.mul(sellPenaltyMultiplier);
        }
        
         if(isTaxActive && !taxless[recipient] && !taxless[sender]){
            _burn(sender,_burnFee);
            _transfer(sender,lpWallet,_lpFee);
            _transfer(sender,adminWallet,_adminFee);
            _transfer(sender,projectWallet,_projectFee);
            
            totalBurnFee = totalBurnFee.add(_burnFee);
            totalLpFee = totalLpFee.add(_lpFee);
            totalAdminFee = totalAdminFee.add(_adminFee);
            totalProcotolFee = totalProcotolFee.add(_projectFee);
            
            amount = amount.sub(_burnFee).sub(_lpFee).sub(_adminFee).sub(_projectFee);
        }
        _transfer(sender, recipient, amount);
    }

    function transfer(address recipient, uint256 amount) public override returns (bool) {
         transferWithFee(_msgSender(),recipient,amount);
        return true;
    }

    function transferFrom (address sender, address recipient, uint256 amount) public override returns (bool) {
        transferWithFee(sender,recipient,amount);
        _approve(sender,_msgSender(),_allowances[sender][_msgSender()].sub(amount, 'BEP20: transfer amount exceeds allowance'));
        return true;
    }

    // Copied and modified from YAM code:
    // https://github.com/yam-finance/yam-protocol/blob/master/contracts/token/YAMGovernanceStorage.sol
    // https://github.com/yam-finance/yam-protocol/blob/master/contracts/token/YAMGovernance.sol
    // Which is copied and modified from COMPOUND:
    // https://github.com/compound-finance/compound-protocol/blob/master/contracts/Governance/Comp.sol

    /// @dev A record of each accounts delegate
    mapping (address => address) internal _delegates;

    /// @notice A checkpoint for marking number of votes from a given block
    struct Checkpoint {
        uint32 fromBlock;
        uint256 votes;
    }

    /// @notice A record of votes checkpoints for each account, by index
    mapping (address => mapping (uint32 => Checkpoint)) public checkpoints;

    /// @notice The number of checkpoints for each account
    mapping (address => uint32) public numCheckpoints;

    /// @notice The EIP-712 typehash for the contract's domain
    bytes32 public constant DOMAIN_TYPEHASH = keccak256("EIP712Domain(string name,uint256 chainId,address verifyingContract)");

    /// @notice The EIP-712 typehash for the delegation struct used by the contract
    bytes32 public constant DELEGATION_TYPEHASH = keccak256("Delegation(address delegatee,uint256 nonce,uint256 expiry)");

    /// @notice A record of states for signing / validating signatures
    mapping (address => uint) public nonces;

      /// @notice An event thats emitted when an account changes its delegate
    event DelegateChanged(address indexed delegator, address indexed fromDelegate, address indexed toDelegate);

    /// @notice An event thats emitted when a delegate account's vote balance changes
    event DelegateVotesChanged(address indexed delegate, uint previousBalance, uint newBalance);

    /**
     * @notice Delegate votes from `msg.sender` to `delegatee`
     * @param delegator The address to get delegatee for
     */
    function delegates(address delegator)
        external
        view
        returns (address)
    {
        return _delegates[delegator];
    }

   /**
    * @notice Delegate votes from `msg.sender` to `delegatee`
    * @param delegatee The address to delegate votes to
    */
    function delegate(address delegatee) external {
        return _delegate(msg.sender, delegatee);
    }

    /**
     * @notice Delegates votes from signatory to `delegatee`
     * @param delegatee The address to delegate votes to
     * @param nonce The contract state required to match the signature
     * @param expiry The time at which to expire the signature
     * @param v The recovery byte of the signature
     * @param r Half of the ECDSA signature pair
     * @param s Half of the ECDSA signature pair
     */
    function delegateBySig(
        address delegatee,
        uint nonce,
        uint expiry,
        uint8 v,
        bytes32 r,
        bytes32 s
    )
        external
    {
        bytes32 domainSeparator = keccak256(
            abi.encode(
                DOMAIN_TYPEHASH,
                keccak256(bytes(name())),
                getChainId(),
                address(this)
            )
        );

        bytes32 structHash = keccak256(
            abi.encode(
                DELEGATION_TYPEHASH,
                delegatee,
                nonce,
                expiry
            )
        );

        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                domainSeparator,
                structHash
            )
        );

        address signatory = ecrecover(digest, v, r, s);
        require(signatory != address(0), "EGG::delegateBySig: invalid signature");
        require(nonce == nonces[signatory]++, "EGG::delegateBySig: invalid nonce");
        require(now <= expiry, "EGG::delegateBySig: signature expired");
        return _delegate(signatory, delegatee);
    }

    /**
     * @notice Gets the current votes balance for `account`
     * @param account The address to get votes balance
     * @return The number of current votes for `account`
     */
    function getCurrentVotes(address account)
        external
        view
        returns (uint256)
    {
        uint32 nCheckpoints = numCheckpoints[account];
        return nCheckpoints > 0 ? checkpoints[account][nCheckpoints - 1].votes : 0;
    }

    /**
     * @notice Determine the prior number of votes for an account as of a block number
     * @dev Block number must be a finalized block or else this function will revert to prevent misinformation.
     * @param account The address of the account to check
     * @param blockNumber The block number to get the vote balance at
     * @return The number of votes the account had as of the given block
     */
    function getPriorVotes(address account, uint blockNumber)
        external
        view
        returns (uint256)
    {
        require(blockNumber < block.number, "EGG::getPriorVotes: not yet determined");

        uint32 nCheckpoints = numCheckpoints[account];
        if (nCheckpoints == 0) {
            return 0;
        }

        // First check most recent balance
        if (checkpoints[account][nCheckpoints - 1].fromBlock <= blockNumber) {
            return checkpoints[account][nCheckpoints - 1].votes;
        }

        // Next check implicit zero balance
        if (checkpoints[account][0].fromBlock > blockNumber) {
            return 0;
        }

        uint32 lower = 0;
        uint32 upper = nCheckpoints - 1;
        while (upper > lower) {
            uint32 center = upper - (upper - lower) / 2; // ceil, avoiding overflow
            Checkpoint memory cp = checkpoints[account][center];
            if (cp.fromBlock == blockNumber) {
                return cp.votes;
            } else if (cp.fromBlock < blockNumber) {
                lower = center;
            } else {
                upper = center - 1;
            }
        }
        return checkpoints[account][lower].votes;
    }

    function _delegate(address delegator, address delegatee)
        internal
    {
        address currentDelegate = _delegates[delegator];
        uint256 delegatorBalance = balanceOf(delegator); // balance of underlying EGGs (not scaled);
        _delegates[delegator] = delegatee;

        emit DelegateChanged(delegator, currentDelegate, delegatee);

        _moveDelegates(currentDelegate, delegatee, delegatorBalance);
    }

    function _moveDelegates(address srcRep, address dstRep, uint256 amount) internal {
        if (srcRep != dstRep && amount > 0) {
            if (srcRep != address(0)) {
                // decrease old representative
                uint32 srcRepNum = numCheckpoints[srcRep];
                uint256 srcRepOld = srcRepNum > 0 ? checkpoints[srcRep][srcRepNum - 1].votes : 0;
                uint256 srcRepNew = srcRepOld.sub(amount);
                _writeCheckpoint(srcRep, srcRepNum, srcRepOld, srcRepNew);
            }

            if (dstRep != address(0)) {
                // increase new representative
                uint32 dstRepNum = numCheckpoints[dstRep];
                uint256 dstRepOld = dstRepNum > 0 ? checkpoints[dstRep][dstRepNum - 1].votes : 0;
                uint256 dstRepNew = dstRepOld.add(amount);
                _writeCheckpoint(dstRep, dstRepNum, dstRepOld, dstRepNew);
            }
        }
    }

    function _writeCheckpoint(
        address delegatee,
        uint32 nCheckpoints,
        uint256 oldVotes,
        uint256 newVotes
    )
        internal
    {
        uint32 blockNumber = safe32(block.number, "EGG::_writeCheckpoint: block number exceeds 32 bits");

        if (nCheckpoints > 0 && checkpoints[delegatee][nCheckpoints - 1].fromBlock == blockNumber) {
            checkpoints[delegatee][nCheckpoints - 1].votes = newVotes;
        } else {
            checkpoints[delegatee][nCheckpoints] = Checkpoint(blockNumber, newVotes);
            numCheckpoints[delegatee] = nCheckpoints + 1;
        }

        emit DelegateVotesChanged(delegatee, oldVotes, newVotes);
    }

    function safe32(uint n, string memory errorMessage) internal pure returns (uint32) {
        require(n < 2**32, errorMessage);
        return uint32(n);
    }

    function getChainId() internal pure returns (uint) {
        uint256 chainId;
        assembly { chainId := chainid() }
        return chainId;
    }
}

