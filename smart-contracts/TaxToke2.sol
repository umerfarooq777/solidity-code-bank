// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


/// Company: Decrypted Labs
/// @title Decrypted Labs ERC20 Token Contract
/// @author Umar Farooq
/// @notice Implements an ERC20 token with taxation within Uniswap V2
 
interface IUniswapV2Factory {
    function createPair(
        address tokenA,
        address tokenB
    ) external returns (address pair);
}

/// @dev Indicates a transfer operation failed
error TransferFailed();

/// @dev Indicates an invalid amount was provided
/// @param _amount The invalid amount that triggered the error
error AmountNotValid(uint256 _amount);

/// @dev Indicates that there are insufficient funds for the operation
error InsufficientFunds();

/// @dev Indicates that a user is not allowed to transfer or recieve
error BlacklistUserFound();

/// @dev Indicates that user have exceeded the maximum limit for the operation
/// @param _value The invalid amount that triggered the error
error ExceededMaxTxSellLimit(uint256 _value);

/// @dev Indicates that user have exceeded the maximum limit for bought tokens
/// @param _value The invalid amount that triggered the error
/// @param _user The blacklist user that triggered the error
error ExceededMaxBuyLimit(uint256 _value, address _user);

/// @dev Indicates that user trying to sell tokens before the set time
error SellingNotAllowedYet();

/// @dev Indicates that user trying to buy tokens before the set time
error BuyingNotAllowedYet();

/// @dev Indicates that user trying to set new greater than BASE
error InvalidFee();

contract WRONGA is ERC20, Ownable {

    /// @notice Address of the Wrapped ETH (WETH) token
    address private constant WETH_ADDRESS =
        0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    /// @dev Internal reference to the Uniswap V2 Factory contract
    IUniswapV2Factory private _helperFactory =
        IUniswapV2Factory(0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f);

    /// @dev Base number used for tax calculations
    uint256 private constant BASE = 10000;

    /// @dev pairAddress is the pair addressof pool of this token and WETH
    address private immutable pairAddress;

    /// @dev Address of the admin wallet, used for receiving ETH from token swaps
    address private taxRecepient;

    /// @dev Tax rate for buy transactions
    uint256 private buyTax;

    /// @dev Tax rate for sell transactions
    uint256 private sellTax;

    /// @notice Maximum transaction sell amount limit
    uint256 private maxTxSellAmount;

    /// @notice Maximum user buy amount limit per wallet
    uint256 private maxBuyAmount;

    /// @notice next token sell time limit
    uint256 private sellDuration;


    //A flag to indicate whether buy or sell is allowed for non-whitelisted users
    bool private isTradingEnabled;

    struct User {
        bool isWhitelist;
        bool isBlacklist;
        uint256 totalBought;
        uint256 nextSellTime;

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
    event sellDurationChanged(
        uint256 indexed oldTime,
        uint256 indexed newTime
    );

    receive() external payable {}

    /// @notice Contract constructor
    /// @param _buyTax Buy tax rate
    /// @param _sellTax Sell tax rate
    constructor(
        uint256 _buyTax,
        uint256 _sellTax
    ) ERC20("WRONGA", "WTA") Ownable(_msgSender()) {
        pairAddress = _helperFactory.createPair(address(this), WETH_ADDRESS);
        
        users[owner()].isWhitelist = true;
        users[address(0)].isWhitelist = true;
        users[address(this)].isWhitelist = true;
        _mint(_msgSender(), 6_900_000_000 * 10 ** 18); 
        taxRecepient = owner();
        buyTax = _buyTax;
        sellTax = _sellTax;
        maxTxSellAmount = 100_000 * 10 ** 18;
        maxBuyAmount = 500_000 * 10 ** 18;
        sellDuration = 1 days;
    }


    /// @dev Overrides the ERC20 _update function to include tax logic on buy/sell transactions
    /// @param from Address sending the tokens
    /// @param to Address receiving the tokens
    /// @param value Amount of tokens being transferred
    function _update(
        address from,
        address to,
        uint256 value
    ) internal override {
        User memory fromUser = users[from];
        User memory toUser = users[to];
        if (fromUser.isBlacklist || toUser.isBlacklist)
            revert BlacklistUserFound();
        uint256 taxAmount;

        if (to == pairAddress && !fromUser.isWhitelist) {

            if (fromUser.nextSellTime > block.timestamp || !isTradingEnabled)
                revert SellingNotAllowedYet();

            if (value > maxTxSellAmount)
                revert ExceededMaxTxSellLimit(value);

            taxAmount = (value * sellTax) / BASE;
            value = value - taxAmount;
            fromUser.nextSellTime = block.timestamp + sellDuration; 
            users[from] = fromUser;


        }

        else if (from == pairAddress && !toUser.isWhitelist) {
            if (!isTradingEnabled) revert BuyingNotAllowedYet();

            taxAmount = (value * buyTax) / BASE;

            value = value - taxAmount;
            toUser.totalBought = toUser.totalBought + value;
            if (toUser.totalBought > maxBuyAmount)
                revert ExceededMaxBuyLimit(toUser.totalBought, to);
            users[to] = toUser;
        }

        if (taxAmount > 0) super._update(from, taxRecepient, taxAmount);
        

        super._update(from, to, value);
    }

    /// @notice Change access for non-whitelisted users to buy or sell
    /// @param _isEnabled The new flag for isTradingEnabled
    /// @custom:modifier onlyOwner Restricts the function access to the contract owner.
    function changeIsTradingEnabled(bool _isEnabled) external onlyOwner {
        isTradingEnabled = _isEnabled;
    }

       /// @notice Change the sell tax fee
    /// @dev Emits the SellFeeChanged event
    /// @param _newFee The new sell tax fee
    /// @custom:modifier onlyOwner Restricts the function access to the contract owner.
    function changeSellFee(uint256 _newFee) external onlyOwner {
        if(_newFee > BASE) revert InvalidFee();
        emit SellFeeChanged(sellTax, _newFee);
        sellTax = _newFee;
    }

    /// @notice Change the buy tax fee
    /// @dev Emits the BuyFeeChanged event
    /// @param _newFee The new buy tax fee
    /// @custom:modifier onlyOwner Restricts the function access to the contract owner.
    function changeBuyFee(uint256 _newFee) external onlyOwner {
        if(_newFee > BASE) revert InvalidFee();
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
    function changeMaxBuyAmount(uint256 _maxBuyAmount) external onlyOwner {
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
    /// @dev Emits the sellDurationChanged event
    /// @param _newTime The time when users can sell tokens to be set
    /// @custom:modifier onlyOwner Restricts the function access to the contract owner.
    function changesellDuration(uint256 _newTime) external onlyOwner {
        emit sellDurationChanged(sellDuration, _newTime);
        sellDuration = _newTime;
    }

    /// @notice set the user to be included/excluded from transaction fees
    /// @param _userAddresses The array of address of the user to set
    /// @param _isWhitelist A boolean for the user to set (True means exclude address from the tax, and False is the vise versa)
    /// @custom:modifier onlyOwner Restricts the function access to the contract owner.
    function updateWhitelists(
        address[] memory _userAddresses,
        bool _isWhitelist
    ) external onlyOwner {
        for (uint i; i < _userAddresses.length; ++i) {
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
        for (uint i; i < _userAddresses.length; ++i) {
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
    function getsellDuration() external view returns (uint256) {
        return sellDuration;
    }

    /// @notice Checks if a user is excluded from transaction fees
    /// @param _address The address of the user to check
    function userStatus(
        address _address
    ) external view returns (User memory user) {
        return users[_address];
    }
}
