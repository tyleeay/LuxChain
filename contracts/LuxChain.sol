// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./LuxToken.sol";

contract LuxChain is ERC1155, ERC2981, Ownable {

    uint256 public mintFee = 0.01 ether;
    uint256 private _nextTokenId = 1;
    uint256 public constant MAX_MINT_FEE = 1 ether; 

    LuxToken public luxToken;
    uint256 public luxMintFee = 100 * 10 ** 18;

    struct LuxItem {
        bytes32  nfcHash;
        string   ipfsCID;
        address  brand;
        uint256  mintedAt;
        bool     isActive;
    }

    mapping(uint256 => LuxItem) public items;
    mapping(address => uint256[]) public brandItems;
    mapping(bytes32 => bool) public usedNfcHashes;  
    mapping(address => bool) public authorizedBrands;

    event ItemMinted(
        uint256 indexed tokenId,
        address indexed brand,
        bytes32 nfcHash,
        string  ipfsCID,
        uint256 mintedAt
    );

    event ItemTransferred(
        uint256 indexed tokenId,
        address indexed from,
        address indexed to
    );

    event AuthenticityVerified(
        uint256 indexed tokenId,
        bool    result
    );                          

    event BrandAuthorized(address indexed brand);

    constructor(address luxTokenAddress)
        ERC1155("https://luxchain.io/api/metadata/{id}.json")
        Ownable(msg.sender)
    {
        luxToken = LuxToken(luxTokenAddress);
    }

    function mintItem(
        bytes32 nfcHash,
        string  calldata ipfsCID,
        uint96  royaltyFee
    ) external payable {

        require(msg.value >= mintFee, "Insufficient mint fee");

        require(!usedNfcHashes[nfcHash], "NFC already registered");

        require(authorizedBrands[msg.sender], "Not authorized brand");

        uint256 tokenId = _nextTokenId;
        _nextTokenId++;

        items[tokenId] = LuxItem({
            nfcHash  : nfcHash,
            ipfsCID  : ipfsCID,
            brand    : msg.sender,
            mintedAt : block.timestamp,
            isActive : true
        });

        brandItems[msg.sender].push(tokenId);

        usedNfcHashes[nfcHash] = true;

        _setTokenRoyalty(tokenId, msg.sender, royaltyFee);

        _mint(msg.sender, tokenId, 1, "");

        emit ItemMinted(tokenId, msg.sender, nfcHash, ipfsCID, block.timestamp);
    }

    function mintItemWithLUX(
        bytes32 nfcHash,
        string calldata ipfsCID,
        uint96 royaltyFee
    ) external {
        require(
            luxToken.balanceOf(msg.sender) >= luxMintFee,
            "Insufficient LUX balance"
        );

        require(authorizedBrands[msg.sender], "Not authorized brand");

        require(!usedNfcHashes[nfcHash], "NFC already registered");

        luxToken.transferFrom(msg.sender, address(this), luxMintFee);
        luxToken.burn(luxMintFee);

        uint256 tokenId = _nextTokenId;
        _nextTokenId++;

        items[tokenId] = LuxItem({
            nfcHash  : nfcHash,
            ipfsCID  : ipfsCID,
            brand    : msg.sender,
            mintedAt : block.timestamp,
            isActive : true
        });

        brandItems[msg.sender].push(tokenId);
        usedNfcHashes[nfcHash] = true;
        _setTokenRoyalty(tokenId, msg.sender, royaltyFee);
        _mint(msg.sender, tokenId, 1, "");

        emit ItemMinted(tokenId, msg.sender, nfcHash, ipfsCID, block.timestamp);
    }

    function verifyAuthenticity(
        uint256 tokenId,
        bytes32 nfcHash
    ) external returns (bool) {

        require(items[tokenId].brand != address(0), "Item does not exist");

        bool result = (items[tokenId].nfcHash == nfcHash);

        emit AuthenticityVerified(tokenId, result);

        return result;
    }

    function getBrandItems(
        address brand
    ) external view returns (uint256[] memory) {
        return brandItems[brand];
    }

    function setMintFee(
        uint256 newFee
    ) external onlyOwner {
        require(newFee <= MAX_MINT_FEE, "Fee exceeds maximum");
        mintFee = newFee;
    }

    function authorizeBrand(address brand) external onlyOwner {
        authorizedBrands[brand] = true;
        emit BrandAuthorized(brand);
    }

    function revokeBrand(address brand) external onlyOwner {
        authorizedBrands[brand] = false;
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC1155, ERC2981)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

}

