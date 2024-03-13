// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";    
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";  
import "@openzeppelin/contracts/interfaces/IERC2981.sol";
import "@openzeppelin/contracts/utils/Strings.sol"; 

error ArbitrumNFT_OnlyOwnerCanCall();
error ArbitrumNFT_NotEnoughBalanceToWithdraw();
error ArbitrumNFT_TransferFailed();
error ArbitrumNFT_PriceNotMatched(uint256 price);
error ArbitrumNFT_SimilarToCurrentPrice(uint256 currentPrice);
error ArbitrumNFT_SimilarToCurrentBaseURI(string currentBaseURI);

contract MYHERBS is ERC721Enumerable, IERC2981, Ownable {

/////////////////////////State Varaibles///////////////////////////////////
    using Strings for uint256;
    string private baseURI;
    uint256 public pricePerNFT;
    uint256 public royalty = 100;
/////////////////////////Mapping///////////////////////////////////////////
    // mapping(uint256 => string) private _tokenURIs;

/////////////////////////Events////////////////////////////////////////////
    event NFTMinted(
        address indexed user,
        uint256 indexed tokenId
     );

    constructor()ERC721("MYHERBS.COM", "ARBI") Ownable(msg.sender){  
        baseURI = "ipfs://QmWa5emrDXAGtw8FVQe3aidEKwTjhQCcrKBqVcMdTWbbik/";
    }

/////////////////////////Main Functions///////////////////////////////////

     function mintNFT(address to) public onlyOwner{

        uint256 mintIndex = totalSupply() + 1;
        _safeMint(to, mintIndex);

        emit NFTMinted(to,mintIndex);
    }
    


/////////////////////////OnlyOwner Functions///////////////////////////////////


    function setBaseURI(string memory _uri) public onlyOwner {
        if(keccak256(abi.encodePacked(baseURI)) == keccak256(abi.encodePacked(_uri))) {
            revert ArbitrumNFT_SimilarToCurrentBaseURI(baseURI);
        }

        baseURI = _uri;
    }


        function changeRoyalty(uint256 _royalty) public onlyOwner {
        royalty = _royalty;
    } 


/////////////////////////View Functions///////////////////////////////////  

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory){
        require(_exists(tokenId),"ERC721URIStorage: URI query for nonexistent token");

         return string(abi.encodePacked(baseURI, tokenId.toString(), ".json"));
    } 

         function supportsInterface(bytes4 interfaceId) public view override (ERC721Enumerable, IERC165) returns (bool){
        return (interfaceId == type(IERC2981).interfaceId || super.supportsInterface(interfaceId));
    }

     function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }

        function royaltyInfo(
        uint256, /*_tokenId*/
        uint256 _salePrice
    )
        external
        view
        override(IERC2981)
        returns (address Receiver, uint256 royaltyAmount)
    {
        return (owner(), (_salePrice * royalty) / 1000); //100*10 = 1000
    }
    
}
