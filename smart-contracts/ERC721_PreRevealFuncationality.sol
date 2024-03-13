// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol"; 

error ERC721MetadataTokenNonExistent();
error totalSupplyExceed();


contract MyToken is ERC721,Ownable {
   using Strings for uint256;
    using Counters for Counters.Counter;
    string private baseURI;
    Counters.Counter private _tokenIdCounter;

    uint256 public supply=3; 

    constructor(string memory _baseuri) ERC721("MyToken", "MTK") {
        baseURI = _baseuri;
    }

    function safeMint(address to) public onlyOwner {
        if(_tokenIdCounter.current()>=supply){
            revert totalSupplyExceed();
        }
        _tokenIdCounter.increment();    
        uint256 tokenId = _tokenIdCounter.current();
        _safeMint(to, tokenId);
    }

    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }
     
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
    if(!_exists(tokenId)){
        revert ERC721MetadataTokenNonExistent();
    }
    string memory URI = _baseURI();
    if(_tokenIdCounter.current()<supply){
        return bytes(URI).length > 0 ? string(abi.encodePacked(baseURI,"preview",".json")): "";
    }else{
        return bytes(URI).length > 0 ? string(abi.encodePacked(baseURI, tokenId.toString(), ".json")): "";
    }
    }

}
