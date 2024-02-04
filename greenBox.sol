//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
contract greeBox {

    uint256 public counter;   
    address public owner;
    IERC20 public _token;    
    uint256 public feeSeller;
    uint256 public feeBuyer;
    uint256 public feesAvailableNativeCoin;
    mapping(uint => greenBox) public greenBoxs;
    mapping(address => bool) whitelistedStablesAddresses;
    mapping(IERC20 => uint) public feesAvailable;

    event greenBoxDeposit(uint indexed orderId, greenBox greenBox);
    event greenBoxComplete(uint indexed orderId, greenBox greenBox);
    event greenBoxDisputeResolved(uint indexed orderId);
  

modifier onlyBuyer(uint _orderId) {
        require(
            msg.sender == greenBoxs[_orderId].buyer,
            "Only Buyer can call this"
        );
        _;
    }
modifier onlySeller(uint _orderId) {
        require(
            msg.sender == greenBoxs[_orderId].seller,
            "Only Seller can call this"
        );
        _;
    }    

 modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }


enum greenBoxStatus {
        Unknown,
        Funded,
        NOT_USED,
        Completed,
        Refund,
        Arbitration
    }

struct greenBox {
        address payable buyer; 
        address payable seller; 
        uint256 value; 
        uint256 sellerfee; 
        uint256 buyerfee; 
        string idImage;  
        IERC20 currency; 
        greenBoxStatus status; 
    }
  constructor(address ERC20Address) {
    owner = msg.sender;
    _token = IERC20(ERC20Address);
    feeSeller = 0;
    feeBuyer = 0;
    counter = 0;
  }

    function setFeeSeller(uint256 _feeSeller) external onlyOwner {
        require(
            _feeSeller >= 0 && _feeSeller <= (1 * 10000),
            "The fee can be from 0% to 1%"
        );
        feeSeller = _feeSeller;
    }

    function setFeeBuyer(uint256 _feeBuyer) external onlyOwner {
        require(
            _feeBuyer >= 0 && _feeBuyer <= (1 * 10000),
            "The fee can be from 0% to 1%"
        );
        feeBuyer = _feeBuyer;
    }
    function setOrderSeller(uint _orderId,string memory _idImage) external onlySeller(_orderId) {
        require(
            greenBoxs[_orderId].status == greenBoxStatus.Funded,
            "USDT has not been deposited"
        );
         greenBoxs[_orderId].status = greenBoxStatus.Completed ;
         greenBoxs[_orderId].idImage = _idImage;
    }


 function creategreenBoxNativeCoin(
        address payable _seller,
        uint256 _value
    ) external payable virtual {
        uint256 _orderId = counter + 1;
        require(msg.sender != _seller, "seller cannot be the same as buyer");
        uint8 _decimals = 18;
        uint256 _amountFeeBuyer = ((_value * (feeBuyer * 10 ** _decimals)) /
            (100 * 10 ** _decimals)) / 1000;
        feeBuyer = _amountFeeBuyer;
        require((_value ) <= msg.value, "Incorrect amount");

        string memory _idImage = "NO IMAGE" ;

        greenBoxs[_orderId] = greenBox(
            payable(msg.sender),
            _seller,
            _value,
            feeSeller,
            feeBuyer,
            _idImage,
            IERC20(address(0)),
            greenBoxStatus.Funded
        );

        counter ++ ;
        emit greenBoxDeposit(_orderId, greenBoxs[_orderId]);

    }

    function releasegreenBoxNativeCoin(
        uint _orderId
    ) external onlyBuyer(_orderId) {
        _releasegreenBoxNativeCoin(_orderId);
    }

 function _releasegreenBoxNativeCoin(uint _orderId) private  onlyBuyer(_orderId) {

        require(
            greenBoxs[_orderId].status == greenBoxStatus.Completed,
            "greenBox its not comppleted"
        );
        uint8 _decimals = 18; //Wei

        uint256 _amountFeeBuyer = ((greenBoxs[_orderId].value *
            (greenBoxs[_orderId].buyerfee * 10 ** _decimals)) /
            (100 * 10 ** _decimals)) / 1000;
        uint256 _amountFeeSeller = ((greenBoxs[_orderId].value *
            (greenBoxs[_orderId].sellerfee * 10 ** _decimals)) /
            (100 * 10 ** _decimals)) / 1000;


        feesAvailableNativeCoin += _amountFeeBuyer + _amountFeeSeller;

/*
        greenBoxs[_orderId].status = greenBoxStatus.Completed;
        (bool sent, ) = greenBoxs[_orderId].seller.call{
            value: (greenBoxs[_orderId].value ) - _amountFeeSeller
        }("");
*/
        uint256 totalAmountToSend = (greenBoxs[_orderId].value * 95) / 100;
        (bool sent, ) = greenBoxs[_orderId].seller.call{
        value: totalAmountToSend
        }("");        
        require(sent, "Transfer failed.");

        emit greenBoxComplete(_orderId, greenBoxs[_orderId]);


    }
   
   function refundBuyerNativeCoin(
        uint _orderId
    ) external  onlyBuyer(_orderId) {
        require(greenBoxs[_orderId].status == greenBoxStatus.Funded,"Refund not approved");
        uint256 _value = greenBoxs[_orderId].value ;
        address _buyer = greenBoxs[_orderId].buyer;
        delete greenBoxs[_orderId];
        (bool sent, ) = payable(address(_buyer)).call{value: _value }("");
        require(sent, "Transfer failed.");

        emit greenBoxDisputeResolved(_orderId);
    }

function withdrawFunds() external onlyOwner {
    require(feesAvailableNativeCoin > 0, "No funds available for withdrawal");

    (bool sent, ) = payable(owner).call{value: feesAvailableNativeCoin}("");
    require(sent, "Withdrawal failed.");

    feesAvailableNativeCoin = 0; // Reset the available funds after withdrawal
}

function getContractBalance() external view onlyOwner returns (uint256) {
    return address(this).balance;
}




}
