// SPDX-License-Identifier: MIT

/// @title NFsTay 
/// @author Rabeeb Aqdas

pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

///////////////////////////////////////////////Interfaces//////////////////////////////////////////////////////////


interface ITreasury {
    function getMyUSDUpdatedPrice() external view returns (uint256 _myUsdPrice);
}


interface IMyUSD {
    function mint(address recipient, uint256 amount) external returns (bool);
}

///////////////////////////////////////////////Errors//////////////////////////////////////////////////

error PriceNotMet(uint256 tokenId, uint256 price);
error ItemNotForSale(uint256 tokenId);
error NotListed(uint256 tokenId);
error AlreadyListed(uint256 tokenId);
error NotLister(uint256 tokenId);   
error YouAreSeller(uint256 tokenId);    
error ConditionNotMet(uint256 price);   
error NoProceeds();
error NotOwner();
error NotApprovedForMarketplace();
error PriceMustBeAboveZero();
error InvalidCurrency();
error NotEnoughBalance(uint256 amount);
error TransferFailed();
error InvalidLength();

contract NFsTay is
    ReentrancyGuard,
    IERC721Receiver,
    Ownable
{

///////////////////////////////////////////////Structs//////////////////////////////////////////////////////////

    struct Listing {
        address currency;
        uint256 price;
        address seller;
        uint256 timestamp;
    }

///////////////////////////////////////////////Events//////////////////////////////////////////////////

    event ItemListed(
        address indexed seller,
        uint256 indexed tokenId,
        address currencyAddress,
        uint256 price
    );

    event ItemCanceled(
        address indexed seller,
        uint256 indexed tokenId
    );

    event ItemBought(
        address indexed buyer,
        uint256 indexed tokenId,
        address currencyAddress,
        uint256 price
    );

/////////////////////////////////////////State Variables/////////////////////////////////////////////

    uint256 public RockApyPerSecond = 4_826_388_890_000;    
    address private usdcAddress;
    IERC721 private _nftHelper;
    IMyUSD private _myusdHelper;
    ITreasury private _treasuryHelper;

    mapping(uint256 => Listing) private listings;   

    receive() external payable { }

    constructor(
        address _myRocksAddress,
        address _myUsdAddress,
        address _usdcAddress,
        address _treasuryAddress
    ) Ownable(_msgSender()) {

        usdcAddress = _usdcAddress;
        _nftHelper = IERC721(_myRocksAddress);
        _myusdHelper = IMyUSD(_myUsdAddress);
       _treasuryHelper = ITreasury(_treasuryAddress);
    }

    modifier notListed(uint256 tokenId) {
        Listing memory listing = listings[tokenId];
        if (listing.price > 0) revert AlreadyListed(tokenId);
        
        _;
    }

    modifier isListed(uint256 tokenId) {
        Listing memory listing = listings[tokenId];
        if (listing.price == 0) revert NotListed(tokenId);
        
        _;
    }
    function _currenyValidation(address currency) private view returns (bool) {
        if(currency == address(_myusdHelper) || currency == usdcAddress || currency == address(0)) return true;
        else return false;
    }

    modifier isOwner(
        uint256 tokenId,
        address spender
    ) {
        address owner = _nftHelper.ownerOf(tokenId);
        if (spender != owner) revert NotLister(tokenId);
        
        _;
    }

    modifier isLister(
        uint256 tokenId,
        address spender
    ) {
        Listing memory listing = listings[tokenId];
        if (listing.seller != spender) revert NotLister(tokenId);
        
        _;
    }

/////////////////////////////////////////Main Functions/////////////////////////////////////////////

    /*
     * @notice Method for listing NFT
     * @param tokenId Token ID of NFT
     * @param currencyAddress the address of token in which you want to sell your NFT
     * @param price the amount at which you want to sell your NFT
     */
    function listItem(
        uint256 tokenId,
        address currencyAddress,
        uint256 price
    )
        external
        notListed(tokenId)
        isOwner(tokenId, _msgSender())
    {
        if (price == 0) revert PriceMustBeAboveZero();
        bool validation = _currenyValidation(currencyAddress);
        if(!validation) revert InvalidCurrency();
        IERC721 nft = _nftHelper;
        if (nft.getApproved(tokenId) != address(this) &&
           !nft.isApprovedForAll(_msgSender(), address(this))
        ) revert NotApprovedForMarketplace();
        nft.safeTransferFrom(_msgSender(), address(this), tokenId);
        listings[tokenId] = Listing(
            currencyAddress,
            price,
            _msgSender(),
            block.timestamp
        );
        emit ItemListed(
            _msgSender(),
            tokenId,
            currencyAddress,
            price
        );
    }

    /*
     * @notice Method for cancelling listing
     * @param tokenId Token ID of NFT
     */
    function cancelListing(
        uint256 tokenId
    )
        external
        isListed(tokenId)
        isLister(tokenId, _msgSender())
    {
        Listing memory listedItem = listings[tokenId];
        _nftHelper.safeTransferFrom(
            address(this),
            _msgSender(),
            tokenId
        );
        uint256 twapPrice = _treasuryHelper.getMyUSDUpdatedPrice();       
        if(twapPrice >= 1.01e18) {
        uint256 time = block.timestamp - listedItem.timestamp;
        uint256 reward = time * RockApyPerSecond;
        _myusdHelper.mint(listedItem.seller,reward);
        }
        delete (listings[tokenId]);
        emit ItemCanceled(_msgSender(), tokenId);
    }

    /*
     * @notice Method for buying listing
     * @param tokenId Token ID of NFT that you want to buy
     */
    function buyItem(
        uint256 tokenId
    )
        external
        payable
        isListed(tokenId)
        nonReentrant
    {

        Listing memory listedItem = listings[tokenId];
        if(listedItem.seller == _msgSender()) revert YouAreSeller(tokenId);
        if (listedItem.currency == address(0)) {
        if (msg.value < ((listedItem.price * 11) / 10)) revert PriceNotMet(tokenId, listedItem.price);
            
        (bool success,) = payable(listedItem.seller).call{value : ((listedItem.price * 9) / 10)}("");
            if(!success) revert TransferFailed();
        } else {
            if (
                IERC20(listedItem.currency).allowance(
                    _msgSender(),
                    address(this)
                ) < ((listedItem.price * 11) / 10)
            ) revert NotApprovedForMarketplace();
            IERC20(listedItem.currency).transferFrom(
                _msgSender(),
                listedItem.seller,
                ((listedItem.price * 9) / 10)
            );
            IERC20(listedItem.currency).transferFrom(
                _msgSender(),
                address(this),
                ((listedItem.price * 2) / 10)
            );
        }
        uint256 twapPrice = _treasuryHelper.getMyUSDUpdatedPrice();       
        if(twapPrice >= 1.01e18) {
        uint256 time = block.timestamp - listedItem.timestamp;
        uint256 reward = time * RockApyPerSecond;
        _myusdHelper.mint(listedItem.seller,reward);
        }
        delete (listings[tokenId]); 
        _nftHelper.safeTransferFrom(
            address(this),
            _msgSender(),
            tokenId
        );
        emit ItemBought(
            _msgSender(),
            tokenId,
            listedItem.currency,
            listedItem.price
        );
    }

    /*
     * @notice Method for updating listing
     * @param tokenId Token ID of NFT
     * @param newPrice Price in Wei of the item
     */
    function updateListing(
        uint256 tokenId,
        address newCurrencyAddress,
        uint256 newPrice
    )
        external
        isListed(tokenId)
        nonReentrant
        isLister(tokenId, _msgSender())
    {
        if (newPrice == 0) revert PriceMustBeAboveZero();
        
        listings[tokenId].price = newPrice;
        listings[tokenId].currency = newCurrencyAddress;
        emit ItemListed(
            _msgSender(),
            tokenId,
            newCurrencyAddress,
            newPrice
        );
    }

     /*
     * @notice Method for collecting reward earned by listing NFT
     * @param tokenIds[] of NFT (maximum 25)
     */

    function collectReward(uint256[] memory _tokenIds)  external {
        uint256 length = _tokenIds.length;
        if(length == 0 ||  length > 25) revert InvalidLength();
        uint256 twapPrice = _treasuryHelper.getMyUSDUpdatedPrice();    
        if(twapPrice < 1.01e18) revert ConditionNotMet(twapPrice); 
    
        uint256 totalTime;
        for(uint256 i ; i < length ; ++i) {
        Listing memory listing = listings[_tokenIds[i]];
        if (listing.price == 0) revert NotListed(_tokenIds[i]);
        if (listing.seller != _msgSender()) revert NotLister(_tokenIds[i]);
        
        totalTime = totalTime + (block.timestamp - listing.timestamp);
        listing.timestamp = block.timestamp;
        listings[_tokenIds[i]] = listing;
        }
        uint256 reward = totalTime * RockApyPerSecond;
        if(reward > 0) _myusdHelper.mint(_msgSender(),reward);
        
    }

/////////////////////////////////////////Ony Owner Functions/////////////////////////////////////////////
    
     /*
     * @notice Method for updating per second APY only for owner
     * @param _RockApyPerSecond per second APY
     */

    function updateAprPerRock(uint256 _RockApyPerSecond) external onlyOwner {
        RockApyPerSecond = _RockApyPerSecond;
    }

    /*
     * @notice Method for withdrawing BNB only for owner
     */

    function withdrawBNB() external onlyOwner {
        address owner = owner();
       uint256 amount = address(this).balance;
        if (amount == 0) revert NotEnoughBalance(amount);
        (bool success,) = payable(owner).call{value : amount}("");
        if(!success) revert TransferFailed();
    }

    /*
     * @notice Method for withdrawing tokens only for owner
     * @param address of token
     */

    function withdrawToken(address token) external onlyOwner {
        address owner = owner();
        bool validation = _currenyValidation(token);
        if(!validation) revert InvalidCurrency();
        uint256 amount = IERC20(token).balanceOf(address(this));
        if (amount == 0) revert NotEnoughBalance(amount);
        IERC20(token).transfer(owner, amount);
    }


/////////////////////////////////////////Getter Functions/////////////////////////////////////////////

    /*
     * @notice Method for get listing
     * @param tokenId Token ID of NFT
     * @returns the details of listed nft
     */

    function getListing(
        uint256 tokenId
    ) external view returns (Listing memory) {
        return listings[tokenId];
    }


    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external pure override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
}
