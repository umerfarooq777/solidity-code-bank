// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

interface IRouter {
    function swapExactETHForTokens(
    uint amountOutMin,
    address[] calldata path,
    address to,
    uint deadline
  ) external payable returns (uint[] memory amounts);

  function getAmountsOut(
    uint amountIn,
    address[] memory path
  ) external view returns (uint[] memory amounts);

}
interface IBEP20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
}

error MultiSig__NotEnoughBalance();
error MultiSig__ConditionNotMetYet();
contract MultiSigWallet {

        struct Transaction {
        address to;
        uint256 value;
        uint256 numConfirmations;
    }
    IBEP20 private bep20helper;
    IRouter private routerhelper;
    AggregatorV3Interface internal priceFeed;   
    Transaction public transaction; 
    uint256 public numConfirmationsRequired;    
    int256 public oldPrice; 
    address private immutable WBNB;
    mapping(address => bool) public isOwner;
    mapping(address => bool) public isConfirmed;
    address[] public owners;    

    event Deposit(address indexed sender, uint256 amount, uint256 balance);
    event SubmitTransaction(address indexed owner,address indexed to,uint256 value);
    event ConfirmTransaction(address indexed owner);
    event RevokeConfirmation(address indexed owner);
    event ExecuteTransaction(address indexed owner);

    modifier onlyOwner() {
        require(isOwner[msg.sender], "not owner");
        _;
    }
    modifier notConfirmed() {
        require(!isConfirmed[msg.sender], "tx already confirmed");
        _;
    }

    constructor(address[] memory _owners, uint256 _numConfirmationsRequired, address _busd,address _router,address _wbnb) {
        require(_owners.length > 0, "owners required");
        require(_numConfirmationsRequired > 0 && _numConfirmationsRequired <= _owners.length,"invalid number of required confirmations");
        for (uint256 i = 0; i < _owners.length; i++) {
            address owner = _owners[i];
            require(owner != address(0), "invalid owner");
            require(!isOwner[owner], "owner not unique");
            isOwner[owner] = true;
            owners.push(owner);
        }
        numConfirmationsRequired = _numConfirmationsRequired;   
         priceFeed = AggregatorV3Interface(0x0567F2323251f0Aab15c8dFb1967E4e8A7D42aeE);
        (,int price,,,) = priceFeed.latestRoundData();
        oldPrice = price;
        //0x10ED43C718714eb63d5aA57B78B54704E256024E
        routerhelper = IRouter(_router);
        //0xe9e7cea3dedca5984780bafc599bd69add087d56
        bep20helper = IBEP20(_busd);
        //0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c
        WBNB = _wbnb;
    }

    receive() external payable {
        emit Deposit(msg.sender, msg.value, address(this).balance);
    }

    function submitTransaction(
        address _to,
        uint256 _value
    ) public onlyOwner {
        require(transaction.value == 0,"First Complete old tx");
        require(_to != address(0) && _value > 0 , "Invalid Params");
        if(_value > bep20helper.balanceOf(address(this))) {
            revert MultiSig__NotEnoughBalance();
        }
        transaction = Transaction({
                to: _to,
                value: _value,
                numConfirmations: 0
            });

        emit SubmitTransaction(msg.sender,_to,_value);
    }

    function confirmTransaction() public onlyOwner notConfirmed() {
        transaction.numConfirmations += 1;
        isConfirmed[msg.sender] = true;

        emit ConfirmTransaction(msg.sender);
    }

    function executeTransaction() public onlyOwner {
        Transaction memory _tx = transaction;
        require(
            _tx.numConfirmations >= numConfirmationsRequired,
            "cannot execute tx"
        );

        (bool success) = bep20helper.transfer(_tx.to, _tx.value);
        require(success, "tx failed");
        delete transaction;
        emit ExecuteTransaction(msg.sender);
    }

    function revokeConfirmation(
    ) public onlyOwner {

        require(isConfirmed[msg.sender], "tx not confirmed");

        transaction.numConfirmations -= 1;
        isConfirmed[msg.sender] = false;

        emit RevokeConfirmation(msg.sender);
    }

    function swapBNBToBUSD() public onlyOwner {
        int256 price = getLatestPrice();
        int256 requiredValue = oldPrice + ((oldPrice / 1000) * 100);
        if(price < requiredValue) revert MultiSig__ConditionNotMetYet();
        oldPrice = price;
        address[] memory path = new address[](2);
        path[0] = WBNB;
        path[1] = address(bep20helper);
        uint256[] memory amount = routerhelper.getAmountsOut(address(this).balance, path);
        routerhelper.swapExactETHForTokens{value: amount[0]}(amount[1], path, address(this),block.timestamp);
    }

    function getOwners() public view returns (address[] memory) {
        return owners;
    }

    function getTransaction() public view returns (
            address to,
            uint256 value,
            uint256 numConfirmations
        )
    {
        Transaction memory trans = transaction;

        return (
            trans.to,
            trans.value,
            trans.numConfirmations
        );
    }
        function getLatestPrice() view public returns (int) {
         (,int price,,,) = priceFeed.latestRoundData();
         return price;
    }

//////////////////////////////////Temp funtions/////////////////////////////////////////////////////////
    function getBUSD(address _addr) public view returns(uint256) {
        return bep20helper.balanceOf(_addr);
    }


    function test() public view returns(bool a,int256 b, int256 c) {
        int price = getLatestPrice();
        if(oldPrice > price + ((price / 1000) * 100)) a = true;
        else a = false;
        b = oldPrice;
        c = price + ((price / 1000) * 100);
    }

        function getPrice(uint256 _price) public view returns (uint256) {
        uint256 temp = uint256(getLatestPrice());
        uint256 price= (((_price * 10 ** 18) / temp) * 10 ** 8);
        return price;
    }

}
