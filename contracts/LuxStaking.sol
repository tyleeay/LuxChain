// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./LuxToken.sol";

contract LuxStaking is Ownable {

    LuxToken public luxToken;

    mapping(address => uint256) public stakedBalance;

    mapping(address => uint256) public stakeTime;

    mapping(address => uint256) public trustScore;

    uint256 public constant MIN_STAKE = 1000 * 10 ** 18;

    event Staked(address indexed brand, uint256 amount);
    event Unstaked(address indexed brand, uint256 amount);
    event Slashed(address indexed brand, uint256 amount);
    event RewardClaimed(address indexed brand, uint256 reward);

    constructor(address luxTokenAddress)
        Ownable(msg.sender)
    {
        luxToken = LuxToken(luxTokenAddress);
    }

    function stake(uint256 amount) external {
        require(amount >= MIN_STAKE, "Below minimum stake");

        luxToken.transferFrom(msg.sender, address(this), amount);

        stakedBalance[msg.sender] += amount;
        stakeTime[msg.sender] = block.timestamp;

        trustScore[msg.sender] = stakedBalance[msg.sender] / (1000 * 10 ** 18);

        emit Staked(msg.sender, amount);
    }

    function unstake() external {
        require(stakedBalance[msg.sender] > 0, "Nothing staked");

        uint256 reward = calculateReward(msg.sender);
        uint256 principal = stakedBalance[msg.sender];

        stakedBalance[msg.sender] = 0;
        stakeTime[msg.sender] = 0;
        trustScore[msg.sender] = 0;

        luxToken.mint(msg.sender, reward);
        luxToken.transfer(msg.sender, principal);

        emit Unstaked(msg.sender, principal);
        emit RewardClaimed(msg.sender, reward);
    }

    function calculateReward(address brand) public view returns (uint256) {
        if (stakedBalance[brand] == 0) return 0;

        uint256 stakedDays = (block.timestamp - stakeTime[brand]) / 1 days;
        return stakedBalance[brand] * stakedDays / 100;
    }

    function slash(address brand) external onlyOwner {
        uint256 amount = stakedBalance[brand];
        require(amount > 0, "Nothing to slash");

        stakedBalance[brand] = 0;
        trustScore[brand] = 0;

        luxToken.burn(amount);

        emit Slashed(brand, amount);
}

}
