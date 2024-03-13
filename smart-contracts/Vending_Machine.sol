// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <=0.9.0;
contract VendingMachine {
    address owner;
    mapping (address => uint) public donut;

    constructor () {
        owner = msg.sender;
        donut[address(this)] = 100;
    }
    modifier onlyOwner() {
        require(msg.sender == owner,"You are not the owner");
        _;
    }   

    function checkQuantity() public view returns(uint){
        return donut[address(this)];
    }

    function checkBalance() public view onlyOwner returns(uint){
        return address(this).balance;
    }

    function purchase(uint amount) public payable{
        require(donut[address(this)] >= amount,"Not enough donuts in stock to fullfill your request");
        require(msg.value >= 1 ether * amount,"Payment in insufficient");

        donut[address(this)] -= amount;
        donut[msg.sender] += amount;

    }    

    function restock(uint _amount) onlyOwner public {
        donut[address(this)] += _amount;
    }

    function getBalance() onlyOwner public {
        require(address(this).balance > 0 ,"There is no cash in machine");
        payable(owner).transfer(address(this).balance);
    }

    

}
