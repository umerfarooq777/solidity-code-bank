// SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

interface IERC20 {

    function balanceOf(address account) external view returns (uint256);

    function transfer(address recipient, uint256 amount)
        external
        returns (bool);

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

}

error HouseRace__AmountNotAvailableToWithdraw();
error HouseRace__TransferFailed();

contract HorseRace is VRFConsumerBaseV2 {
struct Details {
    uint256 amount; 
    address player;
}
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;       
    IERC20 private immutable i_erc20Helper;
    uint256 public busdBalance;            //to be private
    uint256 public gameId;
    bytes32 private immutable i_gasLane;
    uint64 private immutable i_subscriptionId;
    uint32 private constant i_callbackGasLimit = 100000;
    uint32 private constant NUM_WORDS = 1;                                          
    uint16 private constant REQUEST_CONFORMATION = 3;  
    address private wallet1;        
    address private wallet2;        
    mapping (address => uint256) public balances;   //to be private
    mapping (uint256 => Details) public gameRecords;   //to be private
    mapping (uint256 => uint256) public results;

    constructor(address _busd,address vrfCoordinatorV2, bytes32 gasLane,uint64 subscriptionId,address _addr1,address _addr2)VRFConsumerBaseV2(vrfCoordinatorV2) {
        i_erc20Helper = IERC20(_busd);
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinatorV2);
        i_gasLane = gasLane;
        i_subscriptionId = subscriptionId;    
        wallet1 = _addr1;
        wallet2 = _addr2;
    }

    function StakeBusd(uint256 _amount) external {
      require(_amount > 0, "Amount Can't be zero");
      uint256 amountForWallets = (_amount * 300) / 1000; 
      uint256 amountForContract = (_amount * 400) / 1000; 
        (bool success1) = i_erc20Helper.transferFrom(msg.sender, wallet1, amountForWallets);
        if(!success1) {
            revert HouseRace__TransferFailed();
        }
        (bool success2) = i_erc20Helper.transferFrom(msg.sender, wallet2, amountForWallets);
        if(!success2) {
            revert HouseRace__TransferFailed();
        }
     (bool success3) = i_erc20Helper.transferFrom(msg.sender, address(this), amountForContract);
        if(!success3) {
            revert HouseRace__TransferFailed();
        }
      gameId = gameId + 1;
      busdBalance = busdBalance + amountForContract;  
      gameRecords[gameId] = Details(amountForContract,msg.sender);
      i_vrfCoordinator.requestRandomWords(
      i_gasLane, //keyhash
      i_subscriptionId,
      REQUEST_CONFORMATION,
      i_callbackGasLimit,
      NUM_WORDS
    );
    }
    
    function fulfillRandomWords( uint256 /* requestId */,uint256[] memory randomWords) internal override {
        uint256 number = (randomWords[0] % 20) + 1;
       
        uint256 finalRank;  
        if(number > 5) {
            finalRank = number;
        
        }else {
         
      uint256 rank = estimatingWinner(gameRecords[gameId].amount);
      
      if(rank == 0) {
          finalRank = number + 10;
            
      }else if(number < rank) {
      uint256 value = rewardCalculation(rank, gameRecords[gameId].amount);   
      balances[gameRecords[gameId].player] = balances[gameRecords[gameId].player] + value;
      busdBalance = busdBalance - value;
      finalRank = rank; 
         
      }else {
      uint256 value = rewardCalculation(number, gameRecords[gameId].amount);   
      balances[gameRecords[gameId].player] = balances[gameRecords[gameId].player] + value;   
      busdBalance = busdBalance - value;
      finalRank = number;
      }
    }
     results[gameId] = finalRank; 
    }

    function estimatingWinner(uint256 _amount) private view returns(uint256) {
        if(busdBalance >= _amount * 20) {
            return 1;
        }else if(busdBalance >= _amount * 10) {
            return 2;
        }else if(busdBalance >= _amount * 5) {
            return 3;
        }else if(busdBalance >= _amount * 3) {
            return 4;
        }else if(busdBalance >= _amount * 2) {
            return 5;
        }else {
            return 0;
        }
    }

    function rewardCalculation(uint256 _rank,uint256 _amount) private pure returns(uint256) {
        if(_rank == 1) {
            return _amount * 20;
        }else if(_rank == 2) {
            return _amount * 10;
        }else if(_rank == 3) {
            return _amount * 5;
        }else if(_rank == 4) {
            return  _amount * 3;
        }else {
            return _amount * 2;
        }
    }

    function withdraw() external {
        uint256 amount = balances[msg.sender];
       if(amount == 0) {
           revert HouseRace__AmountNotAvailableToWithdraw();
       }
       balances[msg.sender] = 0;
       i_erc20Helper.transfer(msg.sender, amount);
    }
}
