// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0 <=0.9.0;
import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";
contract RandomNumber is VRFConsumerBase {
    bytes32 internal keyHash;
    uint internal fees;
    uint public randomResult;
    constructor() VRFConsumerBase(
         0xb3dCcb4Cf7a26f6cf6B120Cf5A73875B7BBc655B,
     0x01BE23585060835E02B77ef475b0Cc51aA1e0709){
            keyHash = 0x2ed0feb3e7fd2022120aa84fab1945545a9f2ffc9076fd6156fa96eaff4c1311;
            fees = 0.1 * 10 ** 18;
        }
    
    function getRandomNumber() public returns(bytes32 requestId) {
        require(LINK.balanceOf(address(this)) >= fees,"Not enough tokens for contract");
        return requestRandomness(keyHash,fees);
    }

    function fulfillRandomness(bytes32 requestId, uint randomness) internal override {
        randomResult = randomness;
    }
}
