// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <0.9.0;

contract Election {
    struct Vote {
        address voterAddress;
        bool choise;
    }

    struct Voter {
        string voterName;
        bool voted;
    }

    uint private countResult = 0;
    uint public finalResult = 0;
    uint public noOfVoters = 0;
    uint public noOfVotes = 0;

    mapping(uint => Vote) private votes;
    mapping(address => Voter) public voterRegister;

    address public ballotOfficialAddress;
    string public proposal;
    string public agenda;

    enum State{CREATED,VOTING,ENDED}
    State public state;

    modifier onlyOfficial() {
        require(msg.sender == ballotOfficialAddress);
        _;
    }

    modifier inState(State _state) {
        require(state == _state);
        _;
    }

    constructor (string memory _agenda, string memory _proposal) {
        require(bytes(_proposal).length !=0 && bytes(_agenda).length != 0);
        ballotOfficialAddress = msg.sender;
        agenda = _agenda;
        proposal = _proposal;
        state = State.CREATED;
    }

    function addVoter(address _voterAddress,string memory _voterName) onlyOfficial inState(State.CREATED) public{
            Voter memory v;
            v.voterName = _voterName;
            v.voted = false;
            voterRegister[_voterAddress] = v;
            noOfVoters++;
    }
    function startVote() onlyOfficial inState(State.CREATED) public {
        state = State.VOTING;
    }

    function doVote(bool _choice) inState(State.VOTING) public returns(bool _voted) {
        bool found = false;
        if(bytes(voterRegister[msg.sender].voterName).length != 0 && !voterRegister[msg.sender].voted){
            voterRegister[msg.sender].voted = true;
            Vote memory v;
            v.voterAddress = msg.sender;
            v.choise = _choice;
        
            if(_choice) {
                countResult++;
            }
                votes[noOfVotes] = v;
                noOfVotes++;
                found = true;
        }
        return found;
    } 

    function endVoting() onlyOfficial inState(State.VOTING) public {
        state = State.ENDED;
        finalResult = countResult;
    }


}
