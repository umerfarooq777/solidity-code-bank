// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "hardhat/console.sol";
interface IRoyaltyEngineV1 is IERC165 {
    function getRoyalty(address tokenAddress, uint256 tokenId, uint256 value)
        external
        returns (address payable[] memory recipients, uint256[] memory amounts);
    function getRoyaltyView(address tokenAddress, uint256 tokenId, uint256 value)
        external
        view
        returns (address payable[] memory recipients, uint256[] memory amounts);
}
interface IERC721 {
    function mintNFT(address _to,uint256 _count) external;
    function totalSupply() external view returns (uint256);
    function ownerOf(uint256 tokenId) external view returns (address owner);
    function getApproved(uint256 tokenId) external view returns (address operator);
    function safeTransferFrom(address _from,address _to, uint256 _amount) external;
}
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }
    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}
abstract contract Ownable is Context {
    address private _owner;
    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );
    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        _setOwner(_msgSender());
    }
    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }
    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }
    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _setOwner(address(0));
    }
    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(
            newOwner != address(0),
            "Ownable: new owner is the zero address"
        );
        _setOwner(newOwner);
    }
    function _setOwner(address newOwner) private {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}
error NftMarketplace__PriceMustBeAboveZero();
error NftMarketplace__NotApprovedForMarketplace();
error NftMarketplace__AlreadyListed(address nftAddress, uint256 tokenId);
error NftMarketplace__NotOwner();
error NftMarketplace__NotListed(address nftAddress, uint256 tokenId);
error NftMarketplace__PriceNotMet(
    address nftAddress,
    uint256 tokenId,
    uint256 price
);
error NftMarketplace__TransferFailed();
error NftMarketplace__OwnerCantBuyHisItem();
error NftMarketplace__LessThanPreviousOffer(uint256 _offer);
error NftMarketplace__CantMakeOfferOnYourOwnNft();
error NftMarketplace__NotEnoughAllowanceForMarket(uint256 _allowance);
contract MarketPlace is ReentrancyGuard, Ownable {
///////////////////////////////////Struct////////////////////////////////////
 struct Listing {
        uint256 tokenId;
        uint256 price;
        address seller;
    }
struct MakeOffer {
    address requestor;
    uint256 offer;
}
 ///////////////////////////State Variables////////////////////////////////////
    IRoyaltyEngineV1 private registry;
    IERC20 private erc20Helper;
    mapping(address => mapping(uint256 => Listing)) private s_listings;
    mapping(address => mapping(uint256 => MakeOffer)) public s_makeOffer;
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
///////////////////////////////Modifiers//////////////////////////////////
        modifier notListed(
        address nftAddress,
        uint256 tokenId
    ) {
        Listing memory listing = s_listings[nftAddress][tokenId];
        if (listing.price > 0) {
            revert NftMarketplace__AlreadyListed(nftAddress, tokenId);
        }
        _;
    }
    modifier isOwner(
        address nftAddress,
        uint256 tokenId,
        address spender
    ) {
        address owner = IERC721(nftAddress).ownerOf(tokenId);
        if (spender != owner) {
            revert NftMarketplace__NotOwner();
        }
        _;
    }
        modifier isListed(address nftAddress, uint256 tokenId) {
        Listing memory listing = s_listings[nftAddress][tokenId];
        if (listing.price == 0) {
            revert NftMarketplace__NotListed(nftAddress, tokenId);
        }
        _;
    }
    constructor(address _registryAddr,address _wrappedEth) {
        registry = IRoyaltyEngineV1(_registryAddr);
        erc20Helper = IERC20(_wrappedEth);
    }
//////////////////////////////Main functions/////////////////////////////////
     function listItem(address nftAddress, uint256 tokenId, uint256 price)
        external
        notListed(nftAddress, tokenId)
        isOwner(nftAddress, tokenId, _msgSender())
      {
        if (price == 0) {
            revert NftMarketplace__PriceMustBeAboveZero();
        }
        if (IERC721(nftAddress).getApproved(tokenId) != address(this)) {
            revert NftMarketplace__NotApprovedForMarketplace();
        }
        s_listings[nftAddress][tokenId] = Listing(tokenId,price, _msgSender());
            tokenId_records[nftAddress].push(tokenId);
        emit ItemListed(_msgSender(), nftAddress, tokenId, price);
    }
     function cancelListing(address nftAddress, uint256 tokenId)
        external
        isOwner(nftAddress, tokenId, _msgSender())
        isListed(nftAddress, tokenId)
    {
        delete (s_listings[nftAddress][tokenId]);
        removeTokenId(nftAddress,tokenId);
        emit ItemCanceled(_msgSender(), nftAddress, tokenId);
    }
    function updateListing(address nftAddress, uint256 tokenId, uint256 newPrice)
        external
        isOwner(nftAddress, tokenId, _msgSender())
        isListed(nftAddress, tokenId)
    {
        s_listings[nftAddress][tokenId].price = newPrice;
        emit ItemListed(_msgSender(), nftAddress, tokenId, newPrice);
    }
   function buyItems(address nftAddress, uint256 tokenId) external payable isListed(nftAddress, tokenId) nonReentrant {
        Listing memory listing = s_listings[nftAddress][tokenId];
        if(_msgSender() == listing.seller) {
            revert NftMarketplace__OwnerCantBuyHisItem();
        }
        if (msg.value < listing.price) {
            revert NftMarketplace__PriceNotMet(
                nftAddress,
                tokenId,
                listing.price
            );
        }
/////////////////////////////////////////Royality Calculation////////////////////////////////////////
        console.log("HERE");
           (address recipient, uint256 royalty) = checkRoyalty(nftAddress, tokenId, msg.value);
        console.log("HERE");
            if(royalty > 0) {

            uint256 amountToBeSend = msg.value - royalty;

            (bool success, ) = payable(listing.seller).call{value : amountToBeSend}("");
            if(!success) revert NftMarketplace__TransferFailed();
            
            (bool success2,) = payable(recipient).call{value : royalty}("");
            if(!success2) revert NftMarketplace__TransferFailed();
            
            }else{
            (bool success, ) = payable(listing.seller).call{value : msg.value}("");
            if(!success) {
                revert NftMarketplace__TransferFailed();
            }
            }
            delete (s_listings[nftAddress][tokenId]);
            removeTokenId(nftAddress,tokenId);
            if(s_makeOffer[nftAddress][tokenId].offer > 0) {
             delete (s_makeOffer[nftAddress][tokenId]);
            }
            IERC721(nftAddress).safeTransferFrom(
                listing.seller,
                _msgSender(),
                tokenId
            );
            emit ItemBought(_msgSender(), nftAddress, tokenId, listing.price);
    }
function makeOffer(address nftAddress, uint256 tokenId,uint256 _offer) external  {
        require(_offer > 0, "Offer can't be zero");
        if(IERC721(nftAddress).ownerOf(tokenId) == _msgSender()) {
            revert NftMarketplace__CantMakeOfferOnYourOwnNft();
        }
        require(erc20Helper.balanceOf(_msgSender()) >= _offer, "Not enough WETH");
        if(erc20Helper.allowance(_msgSender(),address(this)) < _offer) {
            revert NftMarketplace__NotEnoughAllowanceForMarket(erc20Helper.allowance(_msgSender(),address(this)));
        }
        MakeOffer memory obj = s_makeOffer[nftAddress][tokenId];
        if(obj.offer > _offer) {
            revert NftMarketplace__LessThanPreviousOffer(obj.offer);
        }
        s_makeOffer[nftAddress][tokenId] = MakeOffer(_msgSender(), _offer);
}
function acceptoffer(address nftAddress, uint256 tokenId) external isOwner(nftAddress,tokenId, _msgSender()){
        MakeOffer memory obj = s_makeOffer[nftAddress][tokenId];
        require(obj.offer > 0, "No offer yet!");
        Listing memory listing = s_listings[nftAddress][tokenId];
        if(listing.price > 0) {
        delete (s_listings[nftAddress][tokenId]);
        removeTokenId(nftAddress,tokenId);
        }
        delete (s_makeOffer[nftAddress][tokenId]);
        erc20Helper.transferFrom(obj.requestor,_msgSender(),obj.offer);
        IERC721(nftAddress).safeTransferFrom(
        _msgSender(),
        obj.requestor,
        tokenId
        );
    emit ItemBought(obj.requestor, nftAddress, tokenId, obj.offer);
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
        listings = new Listing[](records.length);
        for(uint256 i = 0 ; i < records.length ; ++i) {
            listings[i] = s_listings[nftAddress][records[i]];
       }
    }
    function checkRoyalty(address nftAddress, uint256 tokenId,uint256 amount) private view returns(address recipent,uint256 royalty){
            (address payable[] memory recipients,uint256[] memory _amount) = registry.getRoyaltyView(nftAddress, tokenId, amount);
            royalty = _amount[0];
            recipent = recipients[0];
    }
}
