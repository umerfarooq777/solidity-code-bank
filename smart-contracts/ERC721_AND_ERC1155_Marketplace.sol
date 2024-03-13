// // SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IERC721 {
    function mintNFT(address _to,uint256 _count) external; 
    function totalSupply() external view returns (uint256);
    function ownerOf(uint256 tokenId) external view returns (address owner);
    function getApproved(uint256 tokenId) external view returns (address operator);
    function safeTransferFrom(address _from,address _to, uint256 _amount) external;
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

error NftMarketplace__PriceMustBeAboveZero();
error NftMarketplace__NotApprovedForMarketplace();
error NftMarketplace__AlreadyListed(address nftAddress, uint256 tokenId,uint256 itemId);
error NftMarketplace__NotOwner();
error NftMarketplace__NotListed(address nftAddress, uint256 tokenId,uint256 itemId);
error NftMarketplace__PriceNotMet(
    address nftAddress,
    uint256 tokenId,
    uint256 price,
    uint256 itemId
);
error NftMarketplace__TransferFailed();
error NftMarketplace__OwnerCantBuyHisItem();
error NftMarketplace__ThisItemIsNotCompatible();
error NftMarketplace__NotEnoughBalance();
error NftMarketplace__QuantityIsNotCorrect();

contract MarketPlace is ReentrancyGuard, Ownable {

///////////////////////////////////Struct////////////////////////////////////
 struct Listing {
        uint256 tokenId;
        uint256 price;
        address seller;
        uint256 quantity;
        uint256 itemId;
    }

 ///////////////////////////State Variables////////////////////////////////////

    IERC20 private erc20Helper;
    mapping(address => mapping(uint256 => mapping(uint256 => Listing))) public s_listings;
    mapping(address => mapping(uint256 => uint256)) public erc1155_Records; 
    mapping(address => uint256[]) public tokenId_records;

//////////////////////////////////////Events////////////////////////////////////////

event ItemListed(
        address indexed seller,
        address indexed nftAddress,
        uint256 indexed tokenId,
        uint256 price
    );

event ItemCanceled(
        address indexed seller,
        address indexed nftAddress,
        uint256 indexed tokenId
    );

event ItemBought(
        address indexed buyer,
        address indexed nftAddress,
        uint256 indexed tokenId,
        uint256 price
    );

///////////////////////////////////////////////Modifiers//////////////////////////////////////////////

        function notListed(
        address nftAddress,
        uint256 tokenId
    )private view returns(bool) {
        Listing memory listing = s_listings[nftAddress][tokenId][1];
        if (listing.price > 0) {
            return false;
        }    else {
            return true;
        }
    }

    function isOwner(
        address nftAddress,
        uint256 tokenId,
        address spender
    )private view returns(bool) {

        address owner = IERC721(nftAddress).ownerOf(tokenId);
        if (spender != owner) {
            return false;
        }else {
            return true;
        }
        
           }

    function isListed(address nftAddress, uint256 tokenId,uint256 itemId) private view returns(bool) {
       
        Listing memory listing = s_listings[nftAddress][tokenId][itemId];
        if (listing.price == 0) {
            return false;
        }else {
            return true;
        } 
    }

    constructor(address _tokenAddress) {
        erc20Helper = IERC20(_tokenAddress);
    } 

//////////////////////////////Main functions/////////////////////////////////
    
     function listItem(address nftAddress, uint256 tokenId, uint256 price,uint256 _quantity)
        external
      {
        if (price == 0) {
            revert NftMarketplace__PriceMustBeAboveZero();
        }

        if(IERC721(nftAddress).supportsInterface(0x80ac58cd)) {

        if(!notListed(nftAddress, tokenId)) {
            revert NftMarketplace__AlreadyListed(nftAddress, tokenId,1);
        }
        if(!isOwner(nftAddress, tokenId, _msgSender())){
            revert NftMarketplace__NotOwner();
        }      
        if (IERC721(nftAddress).getApproved(tokenId) != address(this)) {
            revert NftMarketplace__NotApprovedForMarketplace();
        }
        s_listings[nftAddress][tokenId][1] = Listing(tokenId,price, _msgSender(),1,1);

        }
        else if(IERC1155(nftAddress).supportsInterface(0xd9b67a26)) {
        if(IERC1155(nftAddress).balanceOf(_msgSender(),tokenId) < _quantity) {
            revert NftMarketplace__NotEnoughBalance();
        }
        if (!IERC1155(nftAddress).isApprovedForAll(_msgSender(),address(this))) {
            revert NftMarketplace__NotApprovedForMarketplace();
        }  
        uint256 index = erc1155_Records[nftAddress][tokenId];   

        erc1155_Records[nftAddress][tokenId] = index + 1;   
        s_listings[nftAddress][tokenId][index + 1] = Listing(tokenId,price, _msgSender(),_quantity,index + 1); 

        }else {
            revert NftMarketplace__ThisItemIsNotCompatible();
        }
        if(!_checkTokenIdExists(nftAddress,tokenId)) {
            tokenId_records[nftAddress].push(tokenId);
       }
        emit ItemListed(_msgSender(), nftAddress, tokenId, price);
    }

     function cancelListing(address nftAddress, uint256 tokenId,uint256 itemId)
        external
    {
        if(!isListed(nftAddress, tokenId,itemId)) {
        revert NftMarketplace__NotListed(nftAddress, tokenId,itemId);
        }
    if(IERC721(nftAddress).supportsInterface(0x80ac58cd)) {

        if(!isOwner(nftAddress, tokenId, _msgSender())){
            revert NftMarketplace__NotOwner();
        }  
        delete (s_listings[nftAddress][tokenId][itemId]);
          removeTokenId(nftAddress,tokenId);
    }else if(IERC1155(nftAddress).supportsInterface(0xd9b67a26)) {
        if(s_listings[nftAddress][tokenId][itemId].seller != _msgSender()) {
            revert NftMarketplace__NotOwner();
        }
       delete (s_listings[nftAddress][tokenId][itemId]);
    }else {
            revert NftMarketplace__ThisItemIsNotCompatible();
        }
    emit ItemCanceled(_msgSender(), nftAddress, tokenId);
    }

    function updateListing(address nftAddress, uint256 tokenId, uint256 newPrice,uint256 itemId)
        external
    {
        if(!isListed(nftAddress, tokenId,itemId)) {
        revert NftMarketplace__NotListed(nftAddress, tokenId,itemId);
        }
       if(IERC721(nftAddress).supportsInterface(0x80ac58cd)) {
        if(!isOwner(nftAddress, tokenId, _msgSender())){
            revert NftMarketplace__NotOwner();
        }  
        s_listings[nftAddress][tokenId][itemId].price = newPrice;
       }else if(IERC1155(nftAddress).supportsInterface(0xd9b67a26)) {
        if(s_listings[nftAddress][tokenId][itemId].seller != _msgSender()) {
            revert NftMarketplace__NotOwner();
        }
        s_listings[nftAddress][tokenId][itemId].price = newPrice;
       }else {
        revert NftMarketplace__ThisItemIsNotCompatible();    
       }

        emit ItemListed(_msgSender(), nftAddress, tokenId, newPrice);
    }

    function buyItems(address nftAddress, uint256 tokenId,uint256 amount,uint256 itemId,uint256 quantity) external nonReentrant {
        if(!isListed(nftAddress, tokenId,itemId)) {
        revert NftMarketplace__NotListed(nftAddress, tokenId,itemId);
        }
        Listing memory listing = s_listings[nftAddress][tokenId][itemId];  
        if(_msgSender() == listing.seller) {
            revert NftMarketplace__OwnerCantBuyHisItem();
        }
        if(quantity == 0 || quantity > listing.quantity) {
            revert NftMarketplace__QuantityIsNotCorrect();
        }
        if(IERC721(nftAddress).supportsInterface(0x80ac58cd)) {
        if (amount < listing.price) {
            revert NftMarketplace__PriceNotMet(
                nftAddress,
                tokenId,
                listing.price,
                itemId
            );
        }    
        (bool success) = erc20Helper.transferFrom(_msgSender(), owner(), amount);
        if(!success) {
            revert NftMarketplace__TransferFailed();
        }  
            removeTokenId(nftAddress,tokenId);
              IERC721(nftAddress).safeTransferFrom(
                listing.seller,
                _msgSender(),
                tokenId
            );

        }else if(IERC1155(nftAddress).supportsInterface(0xd9b67a26)) {
        uint256 totalAmount = listing.price * quantity;
            if (amount < totalAmount) {
            revert NftMarketplace__PriceNotMet(
                nftAddress,
                tokenId,
                totalAmount,
                itemId
            );
        } 
        (bool success) = erc20Helper.transferFrom(_msgSender(), owner(), amount);
        if(!success) {
            revert NftMarketplace__TransferFailed();
        }   
        IERC1155(nftAddress).safeTransferFrom(listing.seller,_msgSender(),tokenId,quantity,"");
        }else {
        revert NftMarketplace__ThisItemIsNotCompatible();    
       }
        if(listing.quantity == quantity) {
        delete (s_listings[nftAddress][tokenId][itemId]);
        }else {
            listing.quantity = listing.quantity - quantity;
            s_listings[nftAddress][tokenId][itemId] = listing;
        }
        emit ItemBought(_msgSender(), nftAddress, tokenId, listing.price);
    
    }

        function removeTokenId(address _nftAddress,uint256 _tokenId) private {
            uint256[] memory s_tokenids = tokenId_records[_nftAddress];
        for(uint256 i = 0; i<s_tokenids.length; ++i){
            if(_tokenId==s_tokenids[i]){
                for(uint256 j = i; j<s_tokenids.length-1; ++j){
                    s_tokenids[j]= s_tokenids[j+1];
                }
            }
        }
        tokenId_records[_nftAddress] = s_tokenids;
        tokenId_records[_nftAddress].pop();
    }

///////////////////////////////////View Functions///////////////////////////////////////////

    function getListing(address nftAddress) public view returns (Listing[] memory listings) {
        uint256[] memory records = tokenId_records[nftAddress]; 
        if(IERC721(nftAddress).supportsInterface(0x80ac58cd)) {
        listings = new Listing[](records.length);   
        for(uint256 i = 0 ; i < records.length ; ++i) {
            listings[i] = s_listings[nftAddress][records[i]][1];
       }
        }else if(IERC1155(nftAddress).supportsInterface(0xd9b67a26)) {
            uint256 totalLength;
            uint256 index;
            for(uint256 i; i < records.length ; ++i) {
                uint256 length = erc1155_Records[nftAddress][records[i]];
                totalLength = totalLength + length;
            }
            listings = new Listing[](totalLength);
            
            for(uint256 i; i < records.length; ++i) {
                for(uint256 j = 1; j <= erc1155_Records[nftAddress][records[i]] ; ++j) {
                if(s_listings[nftAddress][records[i]][j].price > 0) {
                listings[index] = s_listings[nftAddress][records[i]][j];
                index = index + 1;
                }   
                }
            }

        }
    }

    function _checkTokenIdExists(address nftAddress,uint256 tokenId) private view returns (bool) {
        uint256[] memory records = tokenId_records[nftAddress]; 
        for(uint256 i; i < records.length ; ++i) {
            if(tokenId == records[i]) {
                return true;
            }
        }
        return false;
    }   

}

