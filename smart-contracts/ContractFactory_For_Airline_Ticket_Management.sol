// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

import "./AirlineTicketsManagement.sol";

contract ContractFactory {
AirlineTicketsManagement airline;
address owner;

modifier onlyOwner() {
    require(msg.sender == owner,"You are not allowed to do that");
    _;
}
constructor() {
    owner = msg.sender;
}

function createAirlineTickets() public onlyOwner {
    airline = new AirlineTicketsManagement();
}
}
