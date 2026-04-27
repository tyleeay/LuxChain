// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./LuxToken.sol";

contract LuxDAO is Ownable {

    LuxToken public luxToken;

    // 提案門檻：需持有 1000 LUX 才能提案
    uint256 public constant PROPOSAL_THRESHOLD = 1000 * 10 ** 18;

    // 投票獎勵：每次投票獲得 10 LUX
    uint256 public constant VOTE_REWARD = 10 * 10 ** 18;

    // ── 提案結構 ──────────────────────────────────────
    struct Proposal {
        uint256 id;
        address proposer;       // 誰提的案
        string  description;    // 提案說明
        uint256 yesVotes;       // 贊成票總量
        uint256 noVotes;        // 反對票總量
        bool    executed;       // 是否已執行
        uint256 createdAt;      // 提案時間
    }

    // ── 儲存映射 ──────────────────────────────────────
    mapping(uint256 => Proposal) public proposals;
    // 提案 ID → 提案內容

    mapping(uint256 => mapping(address => bool)) public hasVoted;
    // 提案 ID → 地址 → 是否已投票
    // 防止同一個人投兩次

    uint256 public proposalCount;
    // 總提案數，也當作下一個提案的 ID

    // ── Events ────────────────────────────────────────
    event ProposalCreated(
        uint256 indexed proposalId,
        address indexed proposer,
        string description
    );

    event Voted(
        uint256 indexed proposalId,
        address indexed voter,
        bool support,           // true = 贊成, false = 反對
        uint256 weight          // 投票權重 = 持幣量
    );

    event ProposalExecuted(uint256 indexed proposalId);

    constructor(address luxTokenAddress)
        Ownable(msg.sender)
    {
        luxToken = LuxToken(luxTokenAddress);
    }

    // ── 建立提案 ──────────────────────────────────────
    function createProposal(string calldata description) external {
        // 需持有足夠 $LUX 才能提案
        require(
            luxToken.balanceOf(msg.sender) >= PROPOSAL_THRESHOLD,
            "Need 1000 LUX to propose"
        );

        proposalCount++;

        proposals[proposalCount] = Proposal({
            id          : proposalCount,
            proposer    : msg.sender,
            description : description,
            yesVotes    : 0,
            noVotes     : 0,
            executed    : false,
            createdAt   : block.timestamp
        });

        emit ProposalCreated(proposalCount, msg.sender, description);
    }

    // ── 投票 ──────────────────────────────────────────
    function vote(uint256 proposalId, bool support) external {
        // 提案必須存在
        require(proposals[proposalId].id != 0, "Proposal not found");

        // 不能重複投票
        require(!hasVoted[proposalId][msg.sender], "Already voted");

        // 投票權重 = 持幣量
        uint256 weight = luxToken.balanceOf(msg.sender);
        require(weight > 0, "No LUX balance");

        // 記錄投票
        hasVoted[proposalId][msg.sender] = true;

        if (support) {
            proposals[proposalId].yesVotes += weight;
        } else {
            proposals[proposalId].noVotes += weight;
        }

        // 投票獎勵：送 10 $LUX 給投票者
        luxToken.mint(msg.sender, VOTE_REWARD);

        emit Voted(proposalId, msg.sender, support, weight);
    }

    // ── 執行提案 ──────────────────────────────────────
    function executeProposal(uint256 proposalId) external onlyOwner {
        Proposal storage proposal = proposals[proposalId];

        require(proposal.id != 0, "Proposal not found");
        require(!proposal.executed, "Already executed");

        // 贊成票必須多於反對票
        require(proposal.yesVotes > proposal.noVotes, "Proposal rejected");

        proposal.executed = true;

        emit ProposalExecuted(proposalId);
    }

}
