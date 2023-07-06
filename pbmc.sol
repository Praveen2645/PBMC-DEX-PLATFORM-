// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract PBMCToken is ERC20 {
    uint8 constant _decimals = 18;
    uint256 constant _totalSupply = 2000000 * 10**_decimals; // 21m tokens for distribution

    constructor() ERC20("PBMC", "PBMC") {
        _mint(msg.sender, _totalSupply);
    }
}

contract TestToken is ERC20 {
    uint8 constant _decimals = 18;
    uint256 constant _totalSupply = 2000000 * 10**_decimals; // 21m tokens for distribution

    constructor() ERC20("PRAWIN", "PRA") {
        _mint(msg.sender, _totalSupply);
    }
}
