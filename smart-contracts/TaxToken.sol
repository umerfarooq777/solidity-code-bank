// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// Company: Decrypted Labs
/// @title Decrypted Labs ERC20 Token Contract
/// @author Rabeeb Aqdas
/// @notice Implements an ERC20 token with taxation and Uniswap integration

interface IUniswapV2Factory {

    function getPair(address tokenA, address tokenB)
        external
        view
        returns (address pair);

    function createPair(address tokenA, address tokenB)
        external
        returns (address pair);
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
        returns (
            uint256 amountToken,
            uint256 amountETH,
            uint256 liquidity
        );

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

/// @dev Indicates that user have exceeded the maximum limit for the operation
error ExceededMaxTxLimit(uint256 _value);

contract DecryptedLabs is ERC20, Ownable {
    /// @notice Address of the Uniswap V2 Router
    address constant public UNISWAP_V2_ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;

    /// @notice Address of the Wrapped Ether (WETH) token
    address private constant WETH_ADDRESS = 0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6;       

    /// @dev Internal reference to the Uniswap V2 Factory contract
    IUniswapV2Factory private _helperFactory = IUniswapV2Factory(0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f);   

    /// @dev Internal reference to the Uniswap V2 Router contract
    IUniswapV2Router02 private _helperRouter = IUniswapV2Router02(UNISWAP_V2_ROUTER);

    /// @dev Address of the admin wallet, used for receiving ETH from token swaps
    address private adminWallet;    

    /// @dev Boolean to check whether the trading is enabled or not
    bool private tradingEnabled;     

    /// @dev Base number used for tax calculations
    uint256 private constant BASE = 1000;       

    /// @dev Tax rate for buy transactions
    uint256 private buyTax;  

    /// @dev Tax rate for sell transactions
    uint256 private sellTax;  

    /// @notice Maximum transaction amount limit
    uint256 private maxTxAmount;     

    /// @dev Mapping to keep track of addresses that are excluded from fees
    mapping(address => bool) private _isExcludedFromFees;

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
    event MaxTxAmountChanged(uint256 indexed oldAmount, uint256 indexed newAmount);

    /// @notice Event emitted when the admin wallet address is changed
    /// @param oldWallet The previous admin wallet address
    /// @param newWallet The updated admin wallet address
    event AdminWalletChanged(address indexed oldWallet, address indexed newWallet);

receive() external payable {}

    /// @notice Contract constructor
    /// @param _name Name of the ERC20 token
    /// @param _symbol Symbol of the ERC20 token
    /// @param _buyTax Buy tax rate
    /// @param _sellTax Sell tax rate
    /// @param _adminWallet Address of the admin wallet
    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _buyTax,
        uint256 _sellTax,
        address _adminWallet
    ) ERC20(_name, _symbol) Ownable(_msgSender()) {
        _helperFactory.createPair(address(this), WETH_ADDRESS);
        _isExcludedFromFees[owner()] = true;
        _isExcludedFromFees[address(0)] = true;             
        _isExcludedFromFees[_adminWallet] = true;
        _isExcludedFromFees[address(this)] = true;  
        _mint(_msgSender(), 2100000 * 10 ** 18);  // 21 million tokens         
        adminWallet = _adminWallet;
        buyTax = _buyTax;
        sellTax = _sellTax;
        maxTxAmount = ((totalSupply() * 1) / 100); // 1% maxTransactionAmountTxn

    }

        /// @notice Add liquidity to Uniswap pool
        /// @param _tokenAmt Amount of tokens to add to the pool
        /// @custom:modifier onlyOwner Restricts the function access to the contract owner.
        function addLiquidity(uint256 _tokenAmt) external payable onlyOwner {
        if(_tokenAmt == 0) revert AmountNotValid(_tokenAmt);
        if(_tokenAmt > balanceOf(_msgSender())) revert InsufficientFunds();
        if (allowance(address(this), UNISWAP_V2_ROUTER) == 0) IERC20(address(this)).approve(UNISWAP_V2_ROUTER, type(uint256).max);

        IERC20(address(this)).transferFrom(
            _msgSender(),
            address(this),
            _tokenAmt
        );

        uint256 amountGiven = msg.value;    
       (,uint256 amountETH,) = _helperRouter.addLiquidityETH{ value: amountGiven }(address(this), _tokenAmt, 0, 0,_msgSender(), block.timestamp);
       uint256 remainingAmount = amountGiven - amountETH;
        if(remainingAmount > 0) {
        (bool success,) = _msgSender().call{value: remainingAmount}("");
        if(!success) revert TransferFailed();
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
            !_isExcludedFromFees[_user]
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
        require(amount >= 1000,"amount cant be less than 1000");
        return (amount * percentage) / 1000;
    }

    /// @dev Overrides the ERC20 _update function to include tax logic
    /// @param from Address sending the tokens
    /// @param to Address receiving the tokens
    /// @param value Amount of tokens being transferred
    function _update(address from, address to, uint256 value) internal override {
        if(!tradingEnabled && !_isExcludedFromFees[from]) revert TradingNotEnabledYet();
        if(value > maxTxAmount && !_isExcludedFromFees[from] && !_isExcludedFromFees[to]) revert ExceededMaxTxLimit(value);
        address pairAddr = _helperFactory.getPair(address(this), WETH_ADDRESS);
        uint256 taxAmount;
        
      if(to == pairAddr && !_isExcludedFromFees[from]) {
            taxAmount = (value * sellTax) / BASE;
            value = value - taxAmount;
        }
      else if(from == pairAddr && !_isExcludedFromFees[to]) {
            taxAmount = (value * buyTax) / BASE;
            value = value - taxAmount;
        }

      if(taxAmount > 0) {
        super._update(from, address(this), taxAmount);
        if(to == pairAddr) _swapTokensForETH();                         
        }

        super._update(from, to, value);    
    }
  
    /// @dev Internal function to swap tokens for ETH
    function _swapTokensForETH() private {
     if (allowance(address(this), UNISWAP_V2_ROUTER) == 0) IERC20(address(this)).approve(UNISWAP_V2_ROUTER, type(uint256).max);
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = WETH_ADDRESS;
         uint256 amount = balanceOf(address(this));
        _helperRouter.swapExactTokensForETHSupportingFeeOnTransferTokens(
            amount,
            0,
            path,
            adminWallet,
            block.timestamp
        );
    }

    /// @notice Change the sell tax fee
    /// @dev Emits the SellFeeChanged event
    /// @param _newFee The new sell tax fee
    /// @custom:modifier onlyOwner Restricts the function access to the contract owner.
    function changeSellFee(uint256 _newFee) external onlyOwner {
        require(_newFee > 0, "Invalid Fee");
        emit SellFeeChanged(sellTax, _newFee);
        sellTax = _newFee;
    }

    /// @notice Change the buy tax fee
    /// @dev Emits the BuyFeeChanged event
    /// @param _newFee The new buy tax fee
    /// @custom:modifier onlyOwner Restricts the function access to the contract owner.
    function changeBuyFee(uint256 _newFee) external onlyOwner {
        require(_newFee > 0, "Invalid Fee");
        emit BuyFeeChanged(buyTax, _newFee);
        buyTax = _newFee;
    }

    /// @notice Change the maximum transaction amount
    /// @dev Emits the MaxTxAmountChanged event
    /// @param _maxTxAmount The new maximum transaction amount to be set
    /// @custom:modifier onlyOwner Restricts the function access to the contract owner.
    function changeMaxTxAmount(uint256 _maxTxAmount) external onlyOwner {
        require(_maxTxAmount > 0, "Invalid Amount");
        emit MaxTxAmountChanged(maxTxAmount, _maxTxAmount);
        maxTxAmount = _maxTxAmount;
    }

    /// @notice Change the admin wallet address
    /// @dev Emits the AdminWalletChanged event
    /// @param _adminWallet The new admin wallet address to be set
    /// @custom:modifier onlyOwner Restricts the function access to the contract owner.
    function changeAdminWallet(address _adminWallet) external onlyOwner {
        require(_adminWallet != address(0), "Invalid Amount");
        emit AdminWalletChanged(adminWallet, _adminWallet);
        adminWallet = _adminWallet;
    }

    /// @notice Enable the trading of the token
    /// @custom:modifier onlyOwner Restricts the function access to the contract owner.
    function enableTrading() external onlyOwner {
        require(!tradingEnabled, "Trading enabled");
        tradingEnabled = true;
    }

    /// @notice Disable the trading of the token
    /// @custom:modifier onlyOwner Restricts the function access to the contract owner.
    function disableTrading() external onlyOwner {
        require(tradingEnabled, "Trading disabled");
        tradingEnabled = false;
    }

    /// @notice set the user to be exclude from transaction fees
    /// @param _userAddr The address of the user to set
    /// @param _action A boolean for the user to set (True means exclude address from the tax, and False is the vise versa)
    /// @custom:modifier onlyOwner Restricts the function access to the contract owner.
    function updateExcludedFromFees(address _userAddr, bool _action) external onlyOwner {
        require(_isExcludedFromFees[_userAddr] != _action, "In the same state");
        _isExcludedFromFees[_userAddr] = _action;
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

    /// @notice Retrieve the status of trading
    /// @return Boolean value that represents current status of trading    
    function getTradingStatus() external view returns (bool) {
        return tradingEnabled;
    }

    /// @notice Get the maximum transaction amount limit
    /// @return The maximum transaction amount
    function getMaxTxAmount() external view returns (uint256) {
        return maxTxAmount;
    }

    /// @notice Checks if a user is excluded from transaction fees
    /// @param _addr The address of the user to check
    /// @return A boolean indicating whether the user is excluded from fees
    function isExcludedFromFees(address _addr) external view returns (bool) {
        return _isExcludedFromFees[_addr];
    }

}
