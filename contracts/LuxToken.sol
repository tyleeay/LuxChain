// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract LuxToken is ERC20, Ownable {

    mapping(address => bool) public authorizedMinters;

    constructor() 
        ERC20("LuxToken", "LUX")
        Ownable(msg.sender)
    {
        // 初始供應量：1,000,000 LUX 給 owner
        _mint(msg.sender, 1_000_000 * 10 ** decimals());
    }

    function addMinter(address minter) external onlyOwner {
        authorizedMinters[minter] = true;   // ← 加這裡
    }

    // ── 鑄造新代幣（只有 owner 可以呼叫）────────────────
    function mint(address to, uint256 amount) external {
        require(
            msg.sender == owner() || authorizedMinters[msg.sender],
            "Not authorized to mint"
        );
        _mint(to, amount);
    }

    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }

}

