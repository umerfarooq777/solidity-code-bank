// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

contract Escrow {

    enum State{NOT_INITIATED,AWAITING_PAYMENT,AWAITING_DELIVERY,COMPLETED}
    State public currstate;
    bool public sellerIn;
    bool public buyerIn;
    uint public price;
    address public buyer;
    address payable public seller;

    modifier onlyBuyer() {
        require(msg.sender == buyer,"Only buyer can access this function");
        _;
    }

    modifier escrowNotStarted() {
        require(currstate == State.NOT_INITIATED,"Contract is already initialized");
        _;
    }

    constructor(address _buyer, address payable _seller, uint _price) {
        buyer = _buyer;
        seller = _seller;
        price = _price * (1 ether);
    }

    function initializeProcess() escrowNotStarted public {
        if(msg.sender == buyer){
            buyerIn = true;
        }
        if(msg.sender == seller){
            sellerIn = true;
        }
        if(buyerIn && sellerIn){
            currstate = State.AWAITING_PAYMENT;
        }
    } 

    function deposit() onlyBuyer payable public  {
            require(currstate == State.AWAITING_PAYMENT,"Already paid");
            require(msg.value == price,"Wrong deposit amount");
            currstate = State.AWAITING_DELIVERY;
    }

    function confirmDelivery() onlyBuyer payable public {
        require(currstate == State.AWAITING_DELIVERY,"Cannot confirm delivery");
        seller.transfer(price);
        currstate = State.COMPLETED;
    }
    function withdraw() onlyBuyer payable public {
        require(currstate == State.AWAITING_DELIVERY,"Cannot withdraw at this stage");
        payable(msg.sender).transfer(price);
        currstate = State.COMPLETED;
    } 
}
