// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./LuxToken.sol";

contract LuxChain is ERC1155, ERC2981, Ownable {

    // ── 平台設定 ──────────────────────────────────────
    uint256 public mintFee = 0.01 ether;  // 品牌每次 mint 付給平台
    uint256 private _nextTokenId = 1;     // token ID 從 1 開始遞增
    uint256 public constant MAX_MINT_FEE = 1 ether; 

    LuxToken public luxToken;
    uint256 public luxMintFee = 100 * 10 ** 18;
    // 用 $LUX 付費：100 LUX per mint

    // ── 精品資料結構 ──────────────────────────────────
    struct LuxItem {
        bytes32  nfcHash;       // keccak256(chipID) — 防偽用
        string   ipfsCID;       // 皮革照片的 IPFS hash
        address  brand;         // 品牌的 wallet address
        uint256  mintedAt;      // block.timestamp — 出廠時間
        bool     isActive;      // false = 此 NFT 已報廢
    }

    // ── 儲存映射 ──────────────────────────────────────
    mapping(uint256 => LuxItem) public items;
    // tokenId → LuxItem
    // 例如：items[1] = { nfcHash: 0xabc..., brand: 0x123... }

    mapping(address => uint256[]) public brandItems;
    // brand address → 該品牌所有 tokenId 的陣列
    // 例如：brandItems[LV的地址] = [1, 2, 3, 5, 8]

    mapping(bytes32 => bool) public usedNfcHashes;
    // 防止同一個 NFC chip 被 mint 兩次   

    mapping(address => bool) public authorizedBrands;

    // ── Events ────────────────────────────────────────
    event ItemMinted(
        uint256 indexed tokenId,   // 方便用 tokenId 搜尋 log
        address indexed brand,     // 方便用品牌 address 搜尋
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
        bool    result             // true = 真品, false = 假貨
    );                          

    event BrandAuthorized(address indexed brand);

    constructor(address luxTokenAddress)
        ERC1155("https://luxchain.io/api/metadata/{id}.json")
        Ownable(msg.sender)
    {
        luxToken = LuxToken(luxTokenAddress);
    }

    function mintItem(
        bytes32 nfcHash,        // keccak256(chipID) — 由品牌前端計算
        string  calldata ipfsCID, // 皮革照片的 IPFS hash
        uint96  royaltyFee      // 例如 500 = 5%, 250 = 2.5%
    ) external payable {

        // ── 檢查 mint fee ──────────────────────────────
        require(msg.value >= mintFee, "Insufficient mint fee");

        // ── 防止同一個 NFC chip 重複 mint ───────────────
        require(!usedNfcHashes[nfcHash], "NFC already registered");

        require(authorizedBrands[msg.sender], "Not authorized brand");

        // ── 產生 tokenId ───────────────────────────────
        uint256 tokenId = _nextTokenId;
        _nextTokenId++;

        // ── 儲存 LuxItem 資料 ──────────────────────────
        items[tokenId] = LuxItem({
            nfcHash  : nfcHash,
            ipfsCID  : ipfsCID,
            brand    : msg.sender,   // 呼叫者就是品牌
            mintedAt : block.timestamp,
            isActive : true
        });

        // ── 記錄此 tokenId 屬於哪個品牌 ────────────────
        brandItems[msg.sender].push(tokenId);

        // ── 標記此 NFC hash 已使用 ─────────────────────
        usedNfcHashes[nfcHash] = true;

        // ── 設定 royalty（ERC-2981）────────────────────
        _setTokenRoyalty(tokenId, msg.sender, royaltyFee);
        // msg.sender = 品牌收 royalty
        // royaltyFee = basis points (500 = 5%)

        // ── Mint NFT 給品牌 ────────────────────────────
        _mint(msg.sender, tokenId, 1, "");
        // (to, tokenId, amount, data)
        // amount = 1 因為每件精品獨一無二

        // ── 發出 event ─────────────────────────────────
        emit ItemMinted(tokenId, msg.sender, nfcHash, ipfsCID, block.timestamp);
    }

    function mintItemWithLUX(
        bytes32 nfcHash,
        string calldata ipfsCID,
        uint96 royaltyFee
    ) external {
        // ── 檢查 $LUX 餘額夠不夠 ──────────────────────
        require(
            luxToken.balanceOf(msg.sender) >= luxMintFee,
            "Insufficient LUX balance"
        );

        // ── 檢查品牌授權 ───────────────────────────────
        require(authorizedBrands[msg.sender], "Not authorized brand");

        // ── 檢查 NFC 沒有重複 ──────────────────────────
        require(!usedNfcHashes[nfcHash], "NFC already registered");

        // ── 扣除 $LUX 並銷毀（通縮！）─────────────────
        luxToken.transferFrom(msg.sender, address(this), luxMintFee);
        luxToken.burn(luxMintFee);
        // 品牌付的 $LUX 直接被銷毀
        // 不是給平台，而是減少總供應量

        // ── 其餘邏輯跟 mintItem() 一樣 ────────────────
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

        // ── 確認 tokenId 存在 ──────────────────────────
        require(items[tokenId].brand != address(0), "Item does not exist");

        // ── 比對 NFC hash ──────────────────────────────
        bool result = (items[tokenId].nfcHash == nfcHash);

        // ── 記錄驗證結果 ───────────────────────────────
        emit AuthenticityVerified(tokenId, result);

        return result;
    }

    function getBrandItems(
        address brand
    ) external view returns (uint256[] memory) {
        return brandItems[brand];
        // 回傳該品牌所有 tokenId 的陣列
        // 例如：[1, 2, 3, 5, 8]
    }

    function setMintFee(
        uint256 newFee
    ) external onlyOwner {
        // onlyOwner → 只有平台 owner 可以調整
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

    // 告訴 Solidity：兩個父合約的 supportsInterface 都要
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC1155, ERC2981)  // 明確指定從哪兩個父合約 override
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
        // super 會自動依序呼叫兩個父合約的版本
    }

}

