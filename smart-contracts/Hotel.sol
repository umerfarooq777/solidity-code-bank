// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <=0.9.0;
contract Hotel {
    address public owner;
    uint private counter;

    struct rentalInfo {
        string name;
        string city;
        string lat;
        string long;
        string unoDescription;
        string dosDescription;
        string imgUrl;
        uint maxGuests;
        uint pricePerDay;
        string[] datesBooked;
        uint id;
        address renter;
    }

    event rentalCreated (
        string name,
        string city,
        string lat,
        string lon,
        string unoDescription,
        string dosDescription,
        string imgUrl,
        uint maxGuests,
        uint pricePerDay,
        string[] datesBooked,
        uint id,
        address renter
    );

    event newDatesBooked (
        string[] datesBooked,
        uint id,
        address booker,
        string city,
        string imgUrl
    );

    mapping(uint => rentalInfo) public rental;
    uint[] private rentalIds;

    constructor() {
        owner = msg.sender;
        counter = 0;
    }

function addRental(
        string memory name,
        string memory city,
        string memory lat,
        string memory long,
        string memory unoDescription,
        string memory dosDescription,
        string memory imgUrl,
        uint maxGuests,
        uint pricePerDay,
        string[] memory datesBooked
) public {
    require(msg.sender == owner,"You are not allowed to do any action in this function");
    rentalInfo storage newRental = rental[counter];
        newRental.name = name;
        newRental.city = city;
        newRental.lat = lat;
        newRental.long = long;
        newRental.unoDescription = unoDescription;
        newRental.dosDescription = dosDescription;
        newRental.imgUrl = imgUrl;
        newRental.maxGuests = maxGuests;
        newRental.pricePerDay = pricePerDay;
        newRental.datesBooked = datesBooked;
        newRental.id = counter;
        newRental.renter = owner;
    rentalIds.push(counter);
    emit rentalCreated(name,city,lat,long,unoDescription,dosDescription,imgUrl,maxGuests,pricePerDay,datesBooked,counter,owner);
        counter++;
}

function checkBookings(uint id, string[] memory newBookings) private view returns(bool) {
    for(uint i=0; i < newBookings.length; i++){
        for(uint j = 0; j < rental[id].datesBooked.length; j++){
            if(keccak256(abi.encodePacked(rental[id].datesBooked[j])) == keccak256(abi.encodePacked(newBookings[i]))){
                return false;
            }
        }
    }
    return true;
}

function addDatesBooked(uint id, string[] memory newBookings) public payable {
    require(id < counter,"ID is incorrect");
    require(checkBookings(id,newBookings), "These Dates are already booked");
    require(msg.value == (rental[id].pricePerDay * 1 ether * newBookings.length),"Price are incorrect");

    for(uint i=0; i<newBookings.length; i++) {
        rental[id].datesBooked.push(newBookings[i]);
    }

    payable(owner).transfer(msg.value);
    emit newDatesBooked(newBookings,counter,msg.sender,rental[id].city,rental[id].imgUrl);
}

function getRental(uint id) public view returns(string memory, uint, string[] memory) {
    require(id < counter, "ID is incorrect");
    // rentalInfo storage s = rental[id];
    // return (s.name,s.pricePerDay,s.datesBooked);
    return (rental[id].name,rental[id].pricePerDay,rental[id].datesBooked);
}


}
