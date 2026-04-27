// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./LuxToken.sol";

contract LuxStaking is Ownable {

    LuxToken public luxToken;

    // ── 質押資料 ──────────────────────────────────────
    mapping(address => uint256) public stakedBalance;
    // 品牌 → 質押了多少 $LUX

    mapping(address => uint256) public stakeTime;
    // 品牌 → 開始質押的時間戳

    mapping(address => uint256) public trustScore;
    // 品牌 → 信任分數（質押越多越高）
    // 買家可以查詢這個分數

    uint256 public constant MIN_STAKE = 1000 * 10 ** 18;
    // 最低質押量：1000 LUX
    // 低於這個數字不給 Verified Brand 徽章

    // ── Events ────────────────────────────────────────
    event Staked(address indexed brand, uint256 amount);
    event Unstaked(address indexed brand, uint256 amount);
    event Slashed(address indexed brand, uint256 amount);
    event RewardClaimed(address indexed brand, uint256 reward);

    constructor(address luxTokenAddress)
        Ownable(msg.sender)
    {
        luxToken = LuxToken(luxTokenAddress);
    }

    // ── 質押 ──────────────────────────────────────────
    function stake(uint256 amount) external {
        require(amount >= MIN_STAKE, "Below minimum stake");

        // 從品牌錢包轉入合約
        luxToken.transferFrom(msg.sender, address(this), amount);

        stakedBalance[msg.sender] += amount;
        stakeTime[msg.sender] = block.timestamp;

        // 信任分數 = 質押量 / 1000 LUX
        trustScore[msg.sender] = stakedBalance[msg.sender] / (1000 * 10 ** 18);

        emit Staked(msg.sender, amount);
    }

    // ── 領獎並取回本金 ─────────────────────────────────
    function unstake() external {
        require(stakedBalance[msg.sender] > 0, "Nothing staked");

        uint256 reward = calculateReward(msg.sender);
        uint256 principal = stakedBalance[msg.sender];

        // 清零（CEI pattern！）
        stakedBalance[msg.sender] = 0;
        stakeTime[msg.sender] = 0;
        trustScore[msg.sender] = 0;

        // 發獎勵 + 還本金
        luxToken.mint(msg.sender, reward);
        luxToken.transfer(msg.sender, principal);

        emit Unstaked(msg.sender, principal);
        emit RewardClaimed(msg.sender, reward);
    }

    // ── 計算獎勵（跟課程一樣：1%/day）────────────────
    function calculateReward(address brand) public view returns (uint256) {
        if (stakedBalance[brand] == 0) return 0;

        uint256 stakedDays = (block.timestamp - stakeTime[brand]) / 1 days;
        return stakedBalance[brand] * stakedDays / 100;
    }

    // ── Slash（造假懲罰，只有 owner 可呼叫）──────────
    function slash(address brand) external onlyOwner {
        uint256 amount = stakedBalance[brand];
        require(amount > 0, "Nothing to slash");

        stakedBalance[brand] = 0;
        trustScore[brand] = 0;

        // 沒收的 $LUX 直接 burn
        luxToken.burn(amount);

        emit Slashed(brand, amount);
}

}
