// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract SavvyFinanceFarmBase is Ownable, AccessControl {
    address constant ZERO_ADDRESS = 0x0000000000000000000000000000000000000000;

    struct ConfigDetails {
        address developmentWallet;
        uint256 minimumTokenNameLength;
        uint256 maximumTokenNameLength;
        uint256 minimumStakingApr;
        uint256 maximumStakingApr;
        uint256 defaultStakingApr;
        uint256 minimumStakeUnstakeFee;
        uint256 maximumStakeUnstakeFee;
        uint256 defaultStakeUnstakeFee;
        uint256 minimumDepositWithdrawFee;
        uint256 maximumDepositWithdrawFee;
        uint256 defaultDepositWithdrawFee;
    }
    ConfigDetails public configData;

    // token => bool
    mapping(address => bool) public isExcludedFromFees;

    // constructor() {
    //     configData.developmentWallet = _msgSender();
    //     configData.minimumTokenNameLength = 2;
    //     configData.maximumTokenNameLength = 10;
    //     configData.minimumStakingApr = _toWei(50);
    //     configData.maximumStakingApr = _toWei(1000);
    //     configData.defaultStakingApr = _toWei(100);
    //     configData.minimumStakeUnstakeFee = 0;
    //     configData.maximumStakeUnstakeFee = _toWei(10);
    //     configData.defaultStakeUnstakeFee = _toWei(1);
    //     configData.minimumDepositWithdrawFee = 0;
    //     configData.maximumDepositWithdrawFee = _toWei(10);
    //     configData.defaultDepositWithdrawFee = _toWei(1);
    //     _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
    // }

    function initialize() external {
        configData.developmentWallet = _msgSender();
        configData.minimumTokenNameLength = 2;
        configData.maximumTokenNameLength = 10;
        configData.minimumStakingApr = _toWei(50);
        configData.maximumStakingApr = _toWei(1000);
        configData.defaultStakingApr = _toWei(100);
        configData.minimumStakeUnstakeFee = 0;
        configData.maximumStakeUnstakeFee = _toWei(10);
        configData.defaultStakeUnstakeFee = _toWei(1);
        configData.minimumDepositWithdrawFee = 0;
        configData.maximumDepositWithdrawFee = _toWei(10);
        configData.defaultDepositWithdrawFee = _toWei(1);
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _transferOwnership(_msgSender());
    }

    function configDevelopmentWallet(address _developmentWallet)
        public
        onlyOwner
    {
        configData.developmentWallet = _developmentWallet;
    }

    function configTokenNameLength(
        uint256 _minimumTokenNameLength,
        uint256 _maximumTokenNameLength
    ) public onlyOwner {
        configData.minimumTokenNameLength = _minimumTokenNameLength;
        configData.maximumTokenNameLength = _maximumTokenNameLength;
    }

    function configStakingApr(
        uint256 _minimumStakingApr,
        uint256 _maximumStakingApr,
        uint256 _defaultStakingApr
    ) public onlyOwner {
        configData.minimumStakingApr = _minimumStakingApr;
        configData.maximumStakingApr = _maximumStakingApr;
        configData.defaultStakingApr = _defaultStakingApr;
    }

    function configStakeUnstakeFees(
        uint256 _minimumStakeUnstakeFee,
        uint256 _maximumStakeUnstakeFee,
        uint256 _defaultStakeUnstakeFee
    ) public onlyOwner {
        configData.minimumStakeUnstakeFee = _minimumStakeUnstakeFee;
        configData.maximumStakeUnstakeFee = _maximumStakeUnstakeFee;
        configData.defaultStakeUnstakeFee = _defaultStakeUnstakeFee;
    }

    function configDepositWithdrawFees(
        uint256 _minimumDepositWithdrawFee,
        uint256 _maximumDepositWithdrawFee,
        uint256 _defaultDepositWithdrawFee
    ) public onlyOwner {
        configData.minimumDepositWithdrawFee = _minimumDepositWithdrawFee;
        configData.maximumDepositWithdrawFee = _maximumDepositWithdrawFee;
        configData.defaultDepositWithdrawFee = _defaultDepositWithdrawFee;
    }

    function excludeFromFees(address _address) public onlyOwner {
        isExcludedFromFees[_address] = true;
    }

    function includeInFees(address _address) public onlyOwner {
        isExcludedFromFees[_address] = false;
    }

    function transferToken(
        address _token,
        address _to,
        uint256 _amount
    ) public onlyOwner {
        IERC20(_token).transfer(_to, _amount);
    }

    function _toWei(uint256 _number) internal pure returns (uint256) {
        return _number * (10**18);
    }

    function _fromWei(uint256 _number) internal pure returns (uint256) {
        return _number / (10**18);
    }

    function _secondsToYears(uint256 _seconds) internal pure returns (uint256) {
        return _fromWei(_seconds * (0.0000000317098 * (10**18)));
    }

    function _calculatePercentage(
        uint256 _percentageValue,
        uint256 _totalAmount
    ) internal pure returns (uint256) {
        return (_totalAmount / _toWei(100)) * _percentageValue;
    }
}
