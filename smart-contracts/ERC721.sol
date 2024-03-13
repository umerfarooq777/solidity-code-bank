// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

interface IERC20 {
    function balanceOf(address user) external view returns(uint);
    function transfer(address reciever, uint amount) external returns(bool);
     function transferFrom(address _from, address _to, uint _value) external returns(bool);
}

contract CyberPunk is ERC721, Ownable {
 
    IERC20 public tokenA;
    IERC20 public tokenB;
    address dev;
    uint256  public constant ONE = 1 ether;
    uint public constant mintRate = 0.05 ether;
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdCounter;


    constructor(IERC20 _tokenA, IERC20 _tokenB) ERC721("CyberPunk", "CP") {
        tokenA = _tokenA;
        tokenB = _tokenB;
        dev = msg.sender;
    }

    // where tokenIndex is token, 0 means tokenA and 1 means tokenB, 2 for eth
    // approval is mandatory first
    function safeMint(uint8 tokenIndex) external payable{
        address user = msg.sender;
        require(tokenIndex < 3, "wrong token index");
        if(tokenIndex == 0) {
         
            uint one_per = 50000000000000000;
            require(tokenA.balanceOf(user) >= (ONE * 5), "insufficient tokenA for minting");        
           (bool sent) =  tokenA.transferFrom(user,dev, one_per);
            (bool sent2) = tokenA.transferFrom(user,address(this), (5000000000000000000 - one_per));
            require(sent && sent2, "transfer failed");
        }
        else if(tokenIndex == 1) {
            uint one_per = 100000000000000000;
            require(tokenB.balanceOf(user) >= (ONE * 10), "insufficient tokenB for minting");
             (bool sent) =  tokenB.transferFrom(user,dev, one_per);
             (bool sent2) = tokenB.transferFrom(user,address(this), (10000000000000000000 - one_per));
             require(sent && sent2, "transfer failed");
        }
        else {
           
            require(msg.value == mintRate,"Not enough coins");
            payable(dev).transfer(500000000000000);

        }
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(user, tokenId);
    }
//press 0 if you want to withdraw token A , 1 for token B and 2 for ethers
   function withdraw(uint paymentType) public onlyOwner {
        require(paymentType < 3, "This type does not exist");
        if(paymentType == 0) {
            tokenA.transfer(dev,tokenA.balanceOf(address(this)));
        }else if(paymentType == 1){
          tokenB.transfer(dev,tokenB.balanceOf(address(this)));

        }else{
            require(address(this).balance > 0 , "Balance is zero");
            payable(owner()).transfer(address(this).balance);
        }
   }
//tokenId is either 0 or 1, 0 means token A and 1 means token B 
    function checkUserBalance(address user,uint tokenId) external view returns(uint){
        require(tokenId < 2,"this token is not exist");
        if(tokenId == 0){
            return tokenA.balanceOf(user);
        }else{
             return tokenB.balanceOf(user);
        }
       }
//owner of the function can check the balance of the contract
       function contractBalance() public view onlyOwner returns(uint) {
           return address(this).balance;
       }
//choice is either 0, 1 or 2, 0 means token A, 1 means token B and 2 means ethers
       function transferNFT(uint choice,address to,uint tokenId) public payable{
           address user = msg.sender;
           require(choice < 3 , "This choise is not available");
           require(to != address(0),"This address does not exist");
           if(choice == 0){
                uint one_per = 50000000000000000;
            require(tokenA.balanceOf(user) >= one_per,"insufficient tokenA for selling this nft");
            (bool sent) =  tokenA.transferFrom(user,dev, one_per);
            require(sent,"Transaction failed");
           }else if(choice == 1){
               uint one_per = 100000000000000000;
               require(tokenB.balanceOf(user) >= one_per,"insufficient tokenB for selling this nft");
               (bool sent) = tokenB.transferFrom(user,dev,one_per);
               require(sent, "Transaction failed");

           }else{
            require(msg.value == 500000000000000, "this is not the 1% fee");
            payable(dev).transfer(500000000000000);
           }
             _transfer(msg.sender,to,tokenId);
       
       }
              
}

