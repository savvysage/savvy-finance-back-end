// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";

contract SavvyFinanceUpgradeable is ERC20Upgradeable, OwnableUpgradeable {
    function initialize(uint256 initialSupply) external initializer {
        __ERC20_init("Savvy Finance", "SVF");
        __Ownable_init();
        _mint(_msgSender(), initialSupply);
        _transferOwnership(_msgSender());
    }
}
