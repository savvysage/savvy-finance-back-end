// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract SavvyFinance is ERC20, Ownable {
    constructor(uint256 initialSupply) ERC20("Savvy Finance", "SVF") {
        _mint(_msgSender(), initialSupply);
    }
}
