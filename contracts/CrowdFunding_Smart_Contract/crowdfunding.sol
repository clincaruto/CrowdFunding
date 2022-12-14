// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.5.0 <0.9.0;

contract CrowdFunding{
    mapping(address => uint) public contributors;
    address public admin;
    uint public noOfContributors;
    uint public minimumContribution;
    uint public deadline; // timestamp
    uint public goal;
    uint public raisedAmount;
    
    // Spending Request
    struct Request{
        string description;
        address payable recipient;
        uint value;
        bool completed; // default value for a bool is false, so by default completed = false.
        uint noOfVoters;
        mapping(address => bool) voters;
    }
    
    // mapping of spending requests
    // the key is the spending request number (index) - starts from zero
    // the value is Request struct
    mapping(uint => Request) public requests;

    // this is neccessary because a mapping does not use or increment indexs automically(like an array does)
    uint public numRequests;

    constructor(uint _goal, uint _deadline){
        goal = _goal;
        deadline = block.timestamp + _deadline;
        minimumContribution = 100 wei;
        admin = msg.sender;
    }
    
    // events to emit
    event ContributeEvent(address _sender, uint _value);
    event CreateRequestEvent(string _description, address _recipient, uint _value);
    event MakePaymentEvent(address _recipient, uint _value);

    function contribute() public payable{
        require(block.timestamp < deadline, "Deadline has passed!");
        require(msg.value >= minimumContribution, "Minimum contribution not met!");
        
        // incrementing the no. of contributors the first time when someone sends eth to the contract
        if(contributors[msg.sender] == 0){
            noOfContributors++;
        }

        contributors[msg.sender] += msg.value;
        raisedAmount += msg.value;

        emit ContributeEvent(msg.sender, msg.value);

    }


    receive() external payable{
        contribute();
    }

    function getBalance() public view returns(uint){
       // require(msg.sender == admin, "You are not an Admin");
        return address(this).balance;
    }
    
    // a contributor can get a refund if goal was not reached within the deadline
    function getRefund() public {
        require(block.timestamp > deadline && raisedAmount < goal);
        require(contributors[msg.sender] > 0);

        address payable recipient = payable(msg.sender);
        uint value = contributors[msg.sender];
        recipient.transfer(value);

        // payable(msg.sender).transfer(contributors[msg.sender]);
        /*Security note: to avoid a re-entrance attack rest the value sent by this contributor BEFORE
        calling the trasfer() function. move this lne before yhe previous one */

        contributors[msg.sender] = 0;
    }

    modifier onlyAdmin{
        require(msg.sender == admin, "Only admin can call this function!");
        _;
    }

    modifier onlyContributors{
        require(contributors[msg.sender] > 0, "You must be a contributor");
        _;
    }

    function createRequest(string memory _description, address payable _recipient, uint _value) public onlyAdmin{
        Request storage newRequest = requests[numRequests];
        numRequests++;

        newRequest.description = _description;
        newRequest.recipient = _recipient;
        newRequest.value = _value;
        newRequest.completed = false;
        newRequest.noOfVoters = 0;

        emit CreateRequestEvent(_description, _recipient, _value);
    }

    function voteRequest(uint _requestNo) public onlyContributors{
        Request storage thisRequest = requests[_requestNo];

        require(thisRequest.voters[msg.sender] == false, "You have already voted!");
        thisRequest.voters[msg.sender] = true;
        thisRequest.noOfVoters++;
    }


    function makePayment(uint _requestNo) public onlyAdmin{
        require(raisedAmount >= goal);
        Request storage thisRequest = requests[_requestNo];
        require(thisRequest.completed == false, "The request has been completed");
        require(thisRequest.noOfVoters > noOfContributors / 2); // 50% voted for ths request
        
        // setting thisRequest as being completed and transfering the money
        thisRequest.recipient.transfer(thisRequest.value);
        thisRequest.completed = true;

        emit MakePaymentEvent(thisRequest.recipient, thisRequest.value);
    }



}
