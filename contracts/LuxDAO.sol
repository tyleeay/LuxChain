// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./LuxToken.sol";

contract LuxDAO is Ownable {

    LuxToken public luxToken;

    uint256 public constant PROPOSAL_THRESHOLD = 1000 * 10 ** 18;

    uint256 public constant VOTE_REWARD = 10 * 10 ** 18;

    struct Proposal {
        uint256 id;
        address proposer;
        string  description;
        uint256 yesVotes;
        uint256 noVotes;
        bool    executed;
        uint256 createdAt;
    }

    mapping(uint256 => Proposal) public proposals;

    mapping(uint256 => mapping(address => bool)) public hasVoted;

    uint256 public proposalCount;

    event ProposalCreated(
        uint256 indexed proposalId,
        address indexed proposer,
        string description
    );

    event Voted(
        uint256 indexed proposalId,
        address indexed voter,
        bool support,
        uint256 weight
    );

    event ProposalExecuted(uint256 indexed proposalId);

    constructor(address luxTokenAddress)
        Ownable(msg.sender)
    {
        luxToken = LuxToken(luxTokenAddress);
    }

    function createProposal(string calldata description) external {
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

    function vote(uint256 proposalId, bool support) external {

        require(proposals[proposalId].id != 0, "Proposal not found");

        require(!hasVoted[proposalId][msg.sender], "Already voted");

        uint256 weight = luxToken.balanceOf(msg.sender);
        require(weight > 0, "No LUX balance");

        hasVoted[proposalId][msg.sender] = true;

        if (support) {
            proposals[proposalId].yesVotes += weight;
        } else {
            proposals[proposalId].noVotes += weight;
        }

        luxToken.mint(msg.sender, VOTE_REWARD);

        emit Voted(proposalId, msg.sender, support, weight);
    }

    function executeProposal(uint256 proposalId) external onlyOwner {
        Proposal storage proposal = proposals[proposalId];

        require(proposal.id != 0, "Proposal not found");
        require(!proposal.executed, "Already executed");

        require(proposal.yesVotes > proposal.noVotes, "Proposal rejected");

        proposal.executed = true;

        emit ProposalExecuted(proposalId);
    }

}
