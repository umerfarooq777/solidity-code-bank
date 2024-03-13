//SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";
import "@chainlink/contracts/src/v0.8/ConfirmedOwner.sol";



contract MultiWordConsumer is ChainlinkClient, ConfirmedOwner {
    using Chainlink for Chainlink.Request;

    bytes32 private jobId;
    uint256 private fee;

    // multiple params returned in a single oracle response
    uint256 public apple;
    uint256 public tesla;
    uint256 public amazon;
    uint256 public volume;

    event RequestMultipleFulfilled(
        bytes32 indexed requestId,
        uint256 apple,
        uint256 tesla,
        uint256 amazon
    );

   
    constructor() ConfirmedOwner(msg.sender) {
        setChainlinkToken(0x779877A7B0D9E8603169DdbD7836e478b4624789);
        setChainlinkOracle(0x6090149792dAAeE9D1D568c9f9a6F6B46AA29eFD);
        jobId = "53f9755920cd451a8fe46f5087468395";
        fee = (1 * LINK_DIVISIBILITY) / 10; // 0,1 * 10**18 (Varies by network and job)
    }

    /**
     * @notice Request mutiple parameters from the oracle in a single transaction
     */
    function requestMultipleParameters() public {
        Chainlink.Request memory req = buildChainlinkRequest(
            jobId,
            address(this),
            this.fulfillMultipleParameters.selector
        );
        req.add(
            "urlBTC",
            "https://min-api.cryptocompare.com/data/price?fsym=AAPL&tsyms=USD"
        );
        req.add("pathBTC", "USD");
        req.add(
            "urlUSD",
            "https://min-api.cryptocompare.com/data/price?fsym=TSLA&tsyms=USD"
        );
        req.add("pathUSD", "USD");
        req.add(
            "urlEUR",
            "https://min-api.cryptocompare.com/data/price?fsym=AMZN&tsyms=USD"
        );
        req.add("pathEUR", "USD");
        sendChainlinkRequest(req, fee); // MWR API.
    }


    function fulfillMultipleParameters(
        bytes32 requestId,
        uint256 appleResponse,
        uint256 teslaResponse,
        uint256 amazonResponse
    ) public recordChainlinkFulfillment(requestId) {
        emit RequestMultipleFulfilled(
            requestId,
           appleResponse,
            teslaResponse,
            amazonResponse
        );
        apple = ((appleResponse * 1 ether) / 100000);
        tesla = ((teslaResponse * 1 ether) / 100000);
        amazon = ((amazonResponse * 1 ether) / 100000);

        volume = (((appleResponse + teslaResponse + amazonResponse) * 1 ether)/100000);
    }


    function withdrawLink() public onlyOwner {
        LinkTokenInterface link = LinkTokenInterface(chainlinkTokenAddress());
        require(
            link.transfer(msg.sender, link.balanceOf(address(this))),
            "Unable to transfer"
        );
    }
}
