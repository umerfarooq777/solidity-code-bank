// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.0 <0.9.0;

contract Petshop{
    address[20] public clients;

    modifier isOwner(uint petid) {
        require(clients[petid] == msg.sender,"you are not the owner of this pet");
        _;
    }

    function buy(uint petid) public {
        require(clients[petid] == address(0),"You already have one pet");
        clients[petid] = msg.sender;
    }

    function getPet(uint petid) public view returns(address){
            return clients[petid];
    }

    function getallpets() public view returns(address[20] memory){
        return clients;
    }

    function disownpet(uint petid) public isOwner(petid) {
        clients[petid] = address(0);
    }

}
