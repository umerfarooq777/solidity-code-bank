// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

contract AirlineTicketsManagement {
    uint economy;
    uint business;
    uint first;
     string _ticket;
         uint _cost;
        bool _booked;
        bool _confrim;
        uint _numberOfTicketsPaid;
    
    address public owner;
      struct User {
        string name;
        string des;
        address pass_id;
        string ticket;
         uint cost;
        bool booked;
        bool confrim;
        uint numberOfTicketsPaid;
    }
    mapping (address => User) public data;

      enum classTypes{FIRST_CLASS,ECONOMY_CLASS,BUSINESS_CLASS}
        classTypes u1;

    constructor() {
        owner = msg.sender;
        economy = 0.005 ether;
        business = 0.007 ether;
        first = 0.01 ether;
    }

    modifier onlyOwner{
        require(msg.sender == owner,"you are not allowed to do that");
        _;
    }

    modifier authanticUser {
        require(data[msg.sender].booked,"you have no booking");
        _;
    }

     receive() external payable {
        require(msg.sender == data[msg.sender].pass_id,"You are not registered");
        require(!data[msg.sender].confrim,"You have already paid the amount");
        require(msg.value == data[msg.sender].cost,"payment is not balanced");
        data[msg.sender].ticket = '';
        data[msg.sender].confrim = true;
        data[msg.sender].cost = 0;
        data[msg.sender].booked = false;
        if(data[msg.sender].confrim == true){
            data[msg.sender].numberOfTicketsPaid++;
            data[msg.sender].confrim = false;
        }
       
    }

    function getBalance() public view onlyOwner returns(uint){
        return address(this).balance;
    }

function setData(string memory _name, string memory _des) public {
    require(msg.sender != data[msg.sender].pass_id,"You are already registered");
    data[msg.sender] = User(_name,_des,msg.sender,_ticket,_cost,_booked,_confrim,_numberOfTicketsPaid);
}

function addUser(address _user,string memory _name, string memory _des) public onlyOwner {
    require(_user != data[_user].pass_id,"this user is already registered");
    data[_user] = User(_name,_des,_user,_ticket,_cost,_booked,_confrim,_numberOfTicketsPaid);
}

function removeUser(address _user) public onlyOwner{
    delete data[_user];
}

function FIRST_CLASS() public {
         require(msg.sender == data[msg.sender].pass_id,"You are not registered");
            require(!data[msg.sender].booked, "you have already book a class");
         u1= classTypes.FIRST_CLASS;
       
             if(uint(u1)==0){
                data[msg.sender].ticket = "First Class";
                data[msg.sender].cost = first;
                 data[msg.sender].booked  = true;
             }
    }

  function ECONOMY_CLASS() public {
          require(msg.sender == data[msg.sender].pass_id,"You are not registered");
        require(!data[msg.sender].booked, "you have already book a class");

         u1= classTypes.ECONOMY_CLASS;
      
             if(uint(u1)==1){
                data[msg.sender].ticket = "Economy Class";
                 data[msg.sender].cost = economy;
                 data[msg.sender].booked = true;
             
             }
    }
     function BUSINESS_CLASS() public {
       require(msg.sender == data[msg.sender].pass_id,"You are not registered");
        require(!data[msg.sender].booked, "you have already book a class");

         u1= classTypes.BUSINESS_CLASS;
        
             if(uint(u1)==2){
                 data[msg.sender].ticket = "Business Class";
                   data[msg.sender].cost = business;
                   data[msg.sender].booked = true;
             }
    }
}

