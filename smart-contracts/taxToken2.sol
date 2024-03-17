// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// Company: Decrypted Labs
/// @title Decrypted Labs ERC20 Token Contract
/// @author Umar Farooq
/// @notice Implements an ERC20 token with taxation and Uniswap integration

interface IUniswapV2Factory {
    function getPair(
        address tokenA,
        address tokenB
    ) external view returns (address pair);

    function createPair(
        address tokenA,
        address tokenB
    ) external returns (address pair);
}

interface IUniswapV2Router02 {
    function addLiquidityETH(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    )
        external
        payable
        returns (uint256 amountToken, uint256 amountETH, uint256 liquidity);

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;
}

/// @dev Indicates a transfer operation failed
error TransferFailed();

/// @dev Indicates an invalid amount was provided
/// @param _amount The invalid amount that triggered the error
error AmountNotValid(uint256 _amount);

/// @dev Indicates that there are insufficient funds for the operation
error InsufficientFunds();

/// @dev Indicates that trading is not enabled yet
error TradingNotEnabledYet();

/// @dev Indicates that trading is not enabled yet
error BlacklistUserFound(address user);

/// @dev Indicates that user have exceeded the maximum limit for the operation
error ExceededMaxTxSellLimit(uint256 _value);

contract DecryptedLabs is ERC20, Ownable {
    /// @notice Address of the Uniswap V2 Router
    address public constant UNISWAP_V2_ROUTER =
        0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;

    /// @notice Address of the Wrapped Ether (WETH) token
    address private constant WETH_ADDRESS =
        0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6;

    /// @dev Internal reference to the Uniswap V2 Factory contract
    IUniswapV2Factory private _helperFactory =
        IUniswapV2Factory(0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f);

    /// @dev Internal reference to the Uniswap V2 Router contract
    IUniswapV2Router02 private _helperRouter =
        IUniswapV2Router02(UNISWAP_V2_ROUTER);

    /// @dev Address of the admin wallet, used for receiving ETH from token swaps
    address private taxRecepient;

    /// @dev Base number used for tax calculations
    uint256 private constant BASE = 10000;

    /// @dev Tax rate for buy transactions
    uint256 private buyTax;

    /// @dev Tax rate for sell transactions
    uint256 private sellTax;

    /// @notice Maximum transaction sell amount limit
    uint256 private maxTxSellAmount;
    
    /// @notice Maximum user buy amount limit per wallet 
    uint256 private maxBuyAmount;

    /// @notice next token sell time limit
    uint256 private nextTokenSellTime;

    struct User {
        bool isWhitelist;
        bool isBlacklist;
        uint256 totalBought;
    }

    /// @dev Mapping to keep track of addresses that are excluded from fees
    mapping(address => User) private users;

    /// @notice Event emitted when the sell fee is changed
    /// @param oldFee The previous sell fee
    /// @param newFee The updated sell fee
    event SellFeeChanged(uint256 indexed oldFee, uint256 indexed newFee);

    /// @notice Event emitted when the buy fee is changed
    /// @param oldFee The previous buy fee
    /// @param newFee The updated buy fee
    event BuyFeeChanged(uint256 indexed oldFee, uint256 indexed newFee);

    /// @notice Event emitted when the maximum transaction amount is changed
    /// @param oldAmount The previous maximum transaction amount
    /// @param newAmount The updated maximum transaction amount
    event MaxTxSellAmountChanged(
        uint256 indexed oldAmount,
        uint256 indexed newAmount
    );

    /// @notice Event emitted when the maximum buy amount per wallet is changed
    /// @param oldAmount The previous maximum buy amount per wallet
    /// @param newAmount The updated maximum buy amount per wallet
    event MaxBuyAmountChanged(
        uint256 indexed oldAmount,
        uint256 indexed newAmount
    );

    /// @notice Event emitted when the admin wallet address is changed
    /// @param oldWallet The previous admin wallet address
    /// @param newWallet The updated admin wallet address
    event TaxRecepientChanged(
        address indexed oldWallet,
        address indexed newWallet
    );

    /// @notice Event emitted when the time users can sell tokens is changed
    /// @param oldTime The previous time when users can sell tokens
    /// @param newTime The updated time when users can sell tokens
    event NextTokenSellTimeChanged(
        uint256 indexed oldTime,
        uint256 indexed newTime
    );

    receive() external payable {}

    /// @notice Contract constructor
    /// @param _buyTax Buy tax rate
    /// @param _sellTax Sell tax rate
    /// @param _taxRecepient Address of the admin wallet
    constructor(
        uint256 _buyTax,
        uint256 _sellTax,
        address _taxRecepient
    ) ERC20("Test Token", "TTK") Ownable(_msgSender()) {

        _helperFactory.createPair(address(this), WETH_ADDRESS);
        users[owner()].isWhitelist = true;
        users[address(0)].isWhitelist = true;
        users[_taxRecepient].isWhitelist = true;
        users[address(this)].isWhitelist = true;
        _mint(_msgSender(), 100_000_000 * 10 ** decimals()); // 100 million tokens
        taxRecepient = _taxRecepient;
        buyTax = _buyTax; //max 99999 = 9.9999 %
        sellTax = _sellTax;  //max 99999 = 9.9999 %
        maxTxSellAmount =  100_000 * 10 ** decimals();
        maxBuyAmount =  500_000 * 10 ** decimals();
        nextTokenSellTime = block.timestamp + 5 minutes;
    }

    /// @notice Add liquidity to Uniswap pool
    /// @param _tokenAmt Amount of tokens to add to the pool
    /// @custom:modifier onlyOwner Restricts the function access to the contract owner.
    function addLiquidity(uint256 _tokenAmt) external payable onlyOwner {
        if (_tokenAmt == 0) revert AmountNotValid(_tokenAmt);
        if (_tokenAmt > balanceOf(_msgSender())) revert InsufficientFunds();
        if (allowance(address(this), UNISWAP_V2_ROUTER) == 0)
            IERC20(address(this)).approve(UNISWAP_V2_ROUTER, type(uint256).max);

        IERC20(address(this)).transferFrom(
            _msgSender(),
            address(this),
            _tokenAmt
        );

        uint256 amountGiven = msg.value;
        (, uint256 amountETH, ) = _helperRouter.addLiquidityETH{
            value: amountGiven
        }(address(this), _tokenAmt, 0, 0, _msgSender(), block.timestamp);
        uint256 remainingAmount = amountGiven - amountETH;
        if (remainingAmount > 0) {
            (bool success, ) = _msgSender().call{value: remainingAmount}("");
            if (!success) revert TransferFailed();
        }
    }

    /// @dev Internal function to calculate the amount of tokens to be transferred after tax
    /// @param _user The address of the user involved in the transfer
    /// @param _amount The amount of tokens to be transferred
    /// @param _taxPercentage The tax percentage to be applied
    /// @return transferedAmount The amount of tokens to be transferred after applying tax
    function _getTransferedTokenAmount(
        address _user,
        uint256 _amount,
        uint256 _taxPercentage
    ) internal view returns (uint256 transferedAmount) {
        return
            !users[_user].isWhitelist
                ? _amount - _calFee(_amount, _taxPercentage)
                : _amount;
    }

    /// @dev Internal function to calculate the fee based on an amount and a percentage
    /// @param amount The amount on which the fee is to be calculated
    /// @param percentage The fee percentage
    /// @return The calculated fee amount
    function _calFee(
        uint256 amount,
        uint256 percentage
    ) internal pure returns (uint256) {
        require(amount >= BASE, "amount cant be less than BASE");
        return (amount * percentage) / BASE;
    }

    /// @dev Overrides the ERC20 _update function to include tax logic
    /// @param from Address sending the tokens
    /// @param to Address receiving the tokens
    /// @param value Amount of tokens being transferred
    function _update(
        address from,
        address to,
        uint256 value
    ) internal override {
        if (users[from].isBlacklist) revert BlacklistUserFound(from);
        if (users[to].isBlacklist) revert BlacklistUserFound(to);
        address pairAddr = _helperFactory.getPair(address(this), WETH_ADDRESS);
        uint256 taxAmount;

        //selling
        if (to == pairAddr && !users[from].isWhitelist) {
            if (value > maxTxSellAmount && !users[to].isWhitelist)
                revert ExceededMaxTxSellLimit(value);
            taxAmount = (value * sellTax) / BASE;
            value = value - taxAmount;
        }
        //buying
        else if (from == pairAddr && !users[to].isWhitelist) {
            taxAmount = (value * buyTax) / BASE;
            value = value - taxAmount;

            //max bought check here
        }

        if (taxAmount > 0) {
            super._update(from, address(this), taxAmount);
            if (to == pairAddr) _swapTokensForETH();
        }

        super._update(from, to, value);
    }

    /// @dev Internal function to swap tokens for ETH
    function _swapTokensForETH() private {
        if (allowance(address(this), UNISWAP_V2_ROUTER) == 0)
            IERC20(address(this)).approve(UNISWAP_V2_ROUTER, type(uint256).max);
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = WETH_ADDRESS;
        uint256 amount = balanceOf(address(this));
        _helperRouter.swapExactTokensForETHSupportingFeeOnTransferTokens(
            amount,
            0,
            path,
            taxRecepient,
            block.timestamp
        );
    }

    /// @notice Change the sell tax fee
    /// @dev Emits the SellFeeChanged event
    /// @param _newFee The new sell tax fee
    /// @custom:modifier onlyOwner Restricts the function access to the contract owner.
    function changeSellFee(uint256 _newFee) external onlyOwner {
        require(_newFee < ((BASE * 10) - 1), "Invalid Fee");
        emit SellFeeChanged(sellTax, _newFee);
        sellTax = _newFee;
    }

    /// @notice Change the buy tax fee
    /// @dev Emits the BuyFeeChanged event
    /// @param _newFee The new buy tax fee
    /// @custom:modifier onlyOwner Restricts the function access to the contract owner.
    function changeBuyFee(uint256 _newFee) external onlyOwner {
        require(_newFee < ((BASE * 10) - 1), "Invalid Fee");
        emit BuyFeeChanged(buyTax, _newFee);
        buyTax = _newFee;
    }

    /// @notice Change the maximum transaction sell amount
    /// @dev Emits the MaxTxSellAmountChanged event
    /// @param _maxTxSellAmount The new maximum transaction amount to be set
    /// @custom:modifier onlyOwner Restricts the function access to the contract owner.
    function changeMaxTxSellAmount(
        uint256 _maxTxSellAmount
    ) external onlyOwner {
        require(_maxTxSellAmount > 0, "Invalid Amount");
        emit MaxTxSellAmountChanged(maxTxSellAmount, _maxTxSellAmount);
        maxTxSellAmount = _maxTxSellAmount;
    }

    /// @notice Change the maximum buy amount per wallet
    /// @dev Emits the MaxTxSellAmountChanged event
    /// @param _maxBuyAmount The new maximum buy amount per wallet to be set
    /// @custom:modifier onlyOwner Restricts the function access to the contract owner.
    function changeMaxBuyAmount(
        uint256 _maxBuyAmount
    ) external onlyOwner {
        require(_maxBuyAmount > 0, "Invalid Amount");
        emit MaxBuyAmountChanged(maxBuyAmount, _maxBuyAmount);
        maxBuyAmount = _maxBuyAmount;
    }

    /// @notice Change the taxRecepient address
    /// @dev Emits the TaxRecepientChanged event
    /// @param _taxRecepient The new taxRecepient address to be set
    /// @custom:modifier onlyOwner Restricts the function access to the contract owner.
    function changeTaxRecepient(address _taxRecepient) external onlyOwner {
        require(_taxRecepient != address(0), "Invalid Address");
        emit TaxRecepientChanged(taxRecepient, _taxRecepient);
        taxRecepient = _taxRecepient;
    }

    /// @notice Change time when users can sell tokens
    /// @dev Emits the NextTokenSellTimeChanged event
    /// @param _newTime The time when users can sell tokens to be set
    /// @custom:modifier onlyOwner Restricts the function access to the contract owner.
    function changeNextTokenSellTime(uint256 _newTime) external onlyOwner {
        require(_newTime > block.timestamp, "Invalid Time");
        emit NextTokenSellTimeChanged(nextTokenSellTime, _newTime);
        nextTokenSellTime = _newTime;
    }

    /// @notice set the user to be included/excluded from transaction fees
    /// @param _userAddresses The array of address of the user to set
    /// @param _isWhitelist A boolean for the user to set (True means exclude address from the tax, and False is the vise versa)
    /// @custom:modifier onlyOwner Restricts the function access to the contract owner.
    function updateWhitelists(
        address[] memory _userAddresses,
        bool _isWhitelist
    ) external onlyOwner {
        for (uint i = 0; i < _userAddresses.length; ++i) {
            require(
                users[_userAddresses[i]].isWhitelist != _isWhitelist,
                "user already in the provided state"
            );
            users[_userAddresses[i]].isWhitelist = _isWhitelist;
        }
    }


    /// @notice set the user to be included/excluded from transaction fees
    /// @param _userAddresses The array of address of the user to set
    /// @param _isBlacklist A boolean for the user to set (True means address blocked for any transfer and recieveing tokens, and False is the vise versa)
    /// @custom:modifier onlyOwner Restricts the function access to the contract owner.
    function updateBlacklists(
        address[] memory _userAddresses,
        bool _isBlacklist
    ) external onlyOwner {
        for (uint i = 0; i < _userAddresses.length; ++i) {
            require(
                users[_userAddresses[i]].isBlacklist != _isBlacklist,
                "user already in the provided state"
            );
            users[_userAddresses[i]].isBlacklist = _isBlacklist;
        }
    }

    /// @notice Retrieve the current sell tax rate
    /// @return The current sell tax rate
    function getSellTax() external view returns (uint256) {
        return sellTax;
    }

    /// @notice Retrieve the current buy tax rate
    /// @return The current buy tax rate
    function getBuyTax() external view returns (uint256) {
        return buyTax;
    }

    /// @notice Get the maximum transaction amount limit
    /// @return The maximum transaction amount
    function getMaxTxSellAmount() external view returns (uint256) {
        return maxTxSellAmount;
    }

     /// @notice Get the maximum buy amount per wallet limit
    /// @return The maximum buy amount per wallet
    function getMaxBuyAmount() external view returns (uint256) {
        return maxBuyAmount;
    }

    /// @notice Get time when users can sell tokens
    /// @return The time when users can sell tokens
    function getNextTokenSellTime() external view returns (uint256) {
        return nextTokenSellTime;
    }

    /// @notice Checks if a user is excluded from transaction fees
    /// @param _address The address of the user to check
    function userStatus(address _address) external view returns (User memory user) {
        return users[_address];
    }
}
