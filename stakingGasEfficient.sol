// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {Pausable} from "@openzeppelin/contracts/security/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**@title Staking Contract
 * @author 
 * @notice This contract is for creating a sample staking contract
 * @dev This implements the Openzeppelin's ERC20 
 */


contract Staking is Pausable, ReentrancyGuard {
    /*errors*/
    //error StakingError(string message);
    error Staking__AddMoreAmount();
    error Staking__AddLessAmount();

    /*state Variables*/
    //openzeppelin variables
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    IERC20 public token;

    //staking variables
    uint256 public minStakeAmount = 20 * 10**14;
    uint256 public maxStakeAmount = 200000 * 10**14;
    address public owner;

    /* events */
    event Staked(address indexed user, uint256 amount, uint256 duration);
    event Unstaked(
        address indexed user,
        uint256 amount,
        uint256 duration,
        uint256 reward
    );

    /*modifiers*/
    modifier onlyOwner() {
        require(msg.sender == owner, "only admins are allowed");
        _;
    }
    /*structs*/
    struct User {
        uint256 amount;
        uint256 deadline;
    }

    /*mappings*/

    mapping(address => mapping(uint256 => User)) public userMonthToAmount;
    mapping(uint256 => uint256) public monthToInterestRate;

    /* fuctions */
    constructor() {
        monthToInterestRate[3] = 22;
        monthToInterestRate[6] = 45;
        monthToInterestRate[12] = 100;
        owner = msg.sender;
    }

    function setAddress(address _address) external onlyOwner {
        token = IERC20(_address);
    }

    function stake(uint256 _amount, uint256 _month)
        external
        whenNotPaused
        nonReentrant
    {
        //require(_amount >= minStakeAmount, "add more amount");
         if (_amount < minStakeAmount) {
            revert Staking__AddMoreAmount();
        }
        //require(_amount <= maxStakeAmount, "add less amount");\
        if(_amount>maxStakeAmount){
            revert Staking__AddLessAmount();
        }
        uint256 interestRate = monthToInterestRate[_month];
        require(interestRate > 0, "invalid month");

        User storage user = userMonthToAmount[msg.sender][_month];
        require(user.amount == 0, "already staked");

        token.safeTransferFrom(msg.sender, address(this), _amount);
        user.amount = _amount;
        user.deadline = block.timestamp.add(_month * 60 * 60 * 24 * 30);
        emit Staked(msg.sender, _amount, _month);
    }

    function unstake(uint256 _month) external nonReentrant {
        User storage user = userMonthToAmount[msg.sender][_month];
        uint256 amount = user.amount;
        require(amount > 0, "no unstake data found");
        require(block.timestamp > user.deadline, "period is not expired");
        uint256 interestRate = monthToInterestRate[_month];
        uint256 reward = calculateReward(amount, interestRate, _month);

        token.safeTransfer(msg.sender, amount.add(reward));
        delete userMonthToAmount[msg.sender][_month];
        emit Unstaked(msg.sender, amount, _month, reward);
    }

    function calculateReward(
        uint256 _amount,
        uint256 _interestRate,
        uint256 _month
    ) public pure returns (uint256) {
        uint256 reward = _amount.mul(_interestRate).mul(_month).div(1000 * 12);
        return reward;
    }

    function updateMinAmount(uint256 _minAmount) external onlyOwner {
        minStakeAmount = _minAmount;
    }

    function updateMaxAmount(uint256 _maxAmount) external onlyOwner {
        maxStakeAmount = _maxAmount;
    }

    function withdraw(uint256 _amount) external onlyOwner {
        uint256 contractBalance = token.balanceOf(address(this));
        require(
            contractBalance >= _amount,
            "Contract does not have enough balance to withdraw"
        );
        token.safeTransfer(msg.sender, _amount);
    }

    function setMonthInterestRate(uint256 _month, uint256 _interestRate)
        external
        onlyOwner
    {
        monthToInterestRate[_month] = _interestRate;
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function transferOwnership(address _address) external onlyOwner {
        owner = _address;
    }
}

