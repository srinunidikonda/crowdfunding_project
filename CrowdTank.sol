// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract CrowdTank {
    struct Project {
        address creator;
        string name;
        string description;
        uint fundingGoal;
        uint deadline;
        uint amountRaised;
        bool funded;
        address highestFunder; 
        uint highestContribution; 
    }
    
    // projectId => project details
    mapping(uint => Project) public projects;
    // projectId => user => contribution amount/funding amount     
    mapping(uint => mapping(address => uint)) public contributions;
    
    // projectId => whether the id is used or not
    mapping(uint => bool) public isIdUsed;
    
    // events
    event ProjectCreated(uint indexed projectId, address indexed creator, string name, string description, uint fundingGoal, uint deadline);
    event ProjectFunded(uint indexed projectId, address indexed contributor, uint amount);
    event FundsWithdrawn(uint indexed projectId, address indexed withdrawer, uint amount, string withdrawerType);
    
    
    //  Added events for withdraw functions
    event UserFundsWithdrawn(uint indexed projectId, address indexed user, uint amount);
    event AdminFundsWithdrawn(uint indexed projectId, address indexed admin, uint amount);
    
    //  Added event for deadline enhancement
    event DeadlineEnhanced(uint indexed projectId, uint oldDeadline, uint newDeadline);
    
    //  Added event for funding goal change
    event FundingGoalChanged(uint indexed projectId, uint oldGoal, uint newGoal);
    
    //  Added event for highest funder tracking
    event HighestFunderUpdated(uint indexed projectId, address indexed newHighestFunder, uint amount);
    
    // create project by a creator
    function createProject(string memory _name, string memory _description, uint _fundingGoal, uint _durationSeconds, uint _id) external {
        require(!isIdUsed[_id], "Project Id is already used");
        isIdUsed[_id] = true;
        projects[_id] = Project({
        creator : msg.sender,
        name : _name,
        description : _description,
        fundingGoal : _fundingGoal,
        deadline : block.timestamp + _durationSeconds,
        amountRaised : 0,
        funded : false,
        highestFunder : address(0), //   highest funder
        highestContribution : 0 // highest contribution
        });
        emit ProjectCreated(_id, msg.sender, _name, _description, _fundingGoal, block.timestamp + _durationSeconds);
    }

    function fundProject(uint _projectId) external payable {
        Project storage project = projects[_projectId];
        require(block.timestamp <= project.deadline, "Project deadline is already passed");
        require(!project.funded, "Project is already funded");
        require(msg.value > 0, "Must send some value of ether");
        
        project.amountRaised += msg.value;
        contributions[_projectId][msg.sender] += msg.value; 

        // Track highest funder
        if (contributions[_projectId][msg.sender] > project.highestContribution) {
            project.highestFunder = msg.sender;
            project.highestContribution = contributions[_projectId][msg.sender];
            emit HighestFunderUpdated(_projectId, msg.sender, contributions[_projectId][msg.sender]);
        }
        
        emit ProjectFunded(_projectId, msg.sender, msg.value);
        if (project.amountRaised >= project.fundingGoal) {
            project.funded = true;
        }
    }

    function userWithdrawFinds(uint _projectId) external {
        Project storage project = projects[_projectId];
        require(project.amountRaised < project.fundingGoal, "Funding goal is reached,user cant withdraw");
        require(block.timestamp > project.deadline, "Deadline has not passed yet"); 
        uint fundContributed = contributions[_projectId][msg.sender];
        require(fundContributed > 0, "No funds to withdraw"); 
        
        contributions[_projectId][msg.sender] = 0; 
        project.amountRaised -= fundContributed; 
        
        // Update highest funder if this user was the highest funder
        if (msg.sender == project.highestFunder) {
            project.highestFunder = address(0);
            project.highestContribution = 0;
        }
        
        payable(msg.sender).transfer(fundContributed);
        
        // Emit event for user withdrawal
        emit UserFundsWithdrawn(_projectId, msg.sender, fundContributed);
        emit FundsWithdrawn(_projectId, msg.sender, fundContributed, "user");
    }

    function adminWithdrawFunds(uint _projectId) external {
        Project storage project = projects[_projectId];
        uint totalFunding = project.amountRaised;
        require(project.funded, "Funding is not sufficient");
        require(project.creator == msg.sender, "Only project admin can withdraw");
        require(project.deadline <= block.timestamp, "Deadline for project is not reached");
        require(totalFunding > 0, "No funds to withdraw"); 
        
        project.amountRaised = 0; 
        payable(msg.sender).transfer(totalFunding);
        
         
        emit AdminFundsWithdrawn(_projectId, msg.sender, totalFunding);
        emit FundsWithdrawn(_projectId, msg.sender, totalFunding, "admin");
    }

    //  Function to enhance deadline
    function enhanceDeadline(uint _projectId, uint _additionalSeconds) external {
        Project storage project = projects[_projectId];
        require(msg.sender == project.creator, "Only project creator can enhance deadline");
        require(!project.funded, "Cannot change deadline of funded project");
        require(block.timestamp <= project.deadline, "Project deadline already passed");
        require(_additionalSeconds > 0, "Additional time must be greater than 0");
        
        uint oldDeadline = project.deadline;
        project.deadline += _additionalSeconds;
        
        emit DeadlineEnhanced(_projectId, oldDeadline, project.deadline);
    }

    //  Function to change funding goal
    function changeFundingGoal(uint _projectId, uint _newFundingGoal) external {
        Project storage project = projects[_projectId];
        require(msg.sender == project.creator, "Only project creator can change funding goal");
        require(!project.funded, "Cannot change funding goal of funded project");
        require(block.timestamp <= project.deadline, "Project deadline already passed");
        require(_newFundingGoal > 0, "Funding goal must be greater than 0");
        require(_newFundingGoal != project.fundingGoal, "New goal must be different from current goal");
        
        uint oldGoal = project.fundingGoal;
        project.fundingGoal = _newFundingGoal;
        
        
        if (project.amountRaised >= project.fundingGoal) {
            project.funded = true;
        } else {
            project.funded = false; 
        }
        
        emit FundingGoalChanged(_projectId, oldGoal, _newFundingGoal);
    }

    //  Separate method for users to withdraw funds before deadline
    function withdrawFundsBeforeDeadline(uint _projectId) external {
        Project storage project = projects[_projectId];
        require(block.timestamp < project.deadline, "Deadline has already passed, use userWithdrawFinds instead");
        require(!project.funded, "Project is already funded, cannot withdraw");
        
        uint fundContributed = contributions[_projectId][msg.sender];
        require(fundContributed > 0, "No funds to withdraw");
        
        contributions[_projectId][msg.sender] = 0; 
        project.amountRaised -= fundContributed; 
        
        // Update highest funder if this user was the highest funder
        if (msg.sender == project.highestFunder) {
            // Find new highest funder (this is a simplified approach)
            project.highestFunder = address(0);
            project.highestContribution = 0;
          
        }
        
        payable(msg.sender).transfer(fundContributed);
        
        emit UserFundsWithdrawn(_projectId, msg.sender, fundContributed);
        emit FundsWithdrawn(_projectId, msg.sender, fundContributed, "user");
    }

   
    function isIdUsedCall(uint _id)external view returns(bool){
        return isIdUsed[_id];
    }
    
    
    function getHighestFunder(uint _projectId) external view returns(address, uint) {
        Project storage project = projects[_projectId];
        return (project.highestFunder, project.highestContribution);
    }
    
    function getProjectDetails(uint _projectId) external view returns(
        address creator,
        string memory name,
        string memory description,
        uint fundingGoal,
        uint deadline,
        uint amountRaised,
        bool funded,
        address highestFunder,
        uint highestContribution
    ) {
        Project storage project = projects[_projectId];
        return (
            project.creator,
            project.name,
            project.description,
            project.fundingGoal,
            project.deadline,
            project.amountRaised,
            project.funded,
            project.highestFunder,
            project.highestContribution
        );
    }
}