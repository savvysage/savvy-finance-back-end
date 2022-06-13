// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./SavvyFinanceFarmBase.sol";

contract SavvyFinanceFarmToken is SavvyFinanceFarmBase {
    // categoryNumber => categoryName
    mapping(uint256 => string) public tokenCategory;
    // token => address => bool
    mapping(address => mapping(address => bool))
        public isExcludedFromTokenAdminFees;

    address[] public tokens;
    struct TokenFeesDetails {
        uint256 devDepositFee;
        uint256 devWithdrawFee;
        uint256 devStakeFee;
        uint256 devUnstakeFee;
        uint256 adminStakeFee;
        uint256 adminUnstakeFee;
    }
    struct TokenDetails {
        // uint256 index;
        bool isActive;
        bool isVerified;
        bool hasMultiTokenRewards;
        string name;
        uint256 category;
        uint256 price;
        uint256 rewardBalance;
        uint256 stakingBalance;
        uint256 stakingApr;
        TokenFeesDetails fees;
        address rewardToken;
        address admin;
        uint256 timestampAdded;
        uint256 timestampLastUpdated;
    }
    mapping(address => TokenDetails) public tokensData;

    function configTokenCategory(uint256 _number, string memory _name)
        public
        onlyOwner
    {
        tokenCategory[_number] = _name;
    }

    function tokenExists(address _token) public view returns (bool) {
        for (uint256 tokenIndex = 0; tokenIndex < tokens.length; tokenIndex++) {
            if (tokens[tokenIndex] == _token) return true;
        }
        return false;
    }

    function getTokens() public view returns (address[] memory) {
        return tokens;
    }

    function getTokenData(address _token)
        public
        view
        returns (TokenDetails memory)
    {
        return tokensData[_token];
    }

    function getTokenRewardValue(address _token) public view returns (uint256) {
        return
            _fromWei(
                tokensData[_token].rewardBalance * tokensData[_token].price
            );
    }

    function setTokenPrice(address _token, uint256 _price) public onlyOwner {
        require(tokenExists(_token), "Token does not exist.");
        tokensData[_token].price = _price;
        tokensData[_token].timestampLastUpdated = block.timestamp;
    }

    function setTokenDevDepositWithdrawFees(
        address _token,
        uint256 _devDepositFee,
        uint256 _devWithdrawFee
    ) public onlyOwner {
        _setTokenDepositWithdrawFees(
            _token,
            _devDepositFee,
            _devWithdrawFee,
            "dev"
        );
    }

    function setTokenDevStakeUnstakeFees(
        address _token,
        uint256 _devStakeFee,
        uint256 _devUnstakeFee
    ) public onlyOwner {
        _setTokenStakeUnstakeFees(_token, _devStakeFee, _devUnstakeFee, "dev");
    }

    function setTokenAdmin(address _token, address _admin) public onlyOwner {
        require(tokenExists(_token), "Token does not exist.");
        if (tokensData[_token].admin != owner())
            revokeRole(_toRole(_token), tokensData[_token].admin);
        tokensData[_token].admin = _admin;
        tokensData[_token].timestampLastUpdated = block.timestamp;
        grantRole(_toRole(_token), tokensData[_token].admin);
    }

    function verifyToken(address _token) public onlyOwner {
        require(tokenExists(_token), "Token does not exist.");
        tokensData[_token].isVerified = true;
    }

    function unverifyToken(address _token) public onlyOwner {
        require(tokenExists(_token), "Token does not exist.");
        tokensData[_token].isVerified = false;
    }

    function addToken(
        address _token,
        string memory _name,
        uint256 _category,
        uint256 _stakingApr,
        uint256 _adminStakeFee,
        uint256 _adminUnstakeFee,
        address _reward_token
    ) public {
        require(!tokenExists(_token), "Token already exists.");
        _setupRole(_toRole(_token), owner());
        _setupRole(_toRole(_token), _msgSender());
        // uint256 index = tokens.length;
        tokens.push(_token);
        // tokensData[_token].index = index;
        tokensData[_token].name = _name;
        tokensData[_token].category = _category;
        tokensData[_token].fees.devDepositFee = configData
            .defaultDepositWithdrawFee;
        tokensData[_token].fees.devWithdrawFee = configData
            .defaultDepositWithdrawFee;
        tokensData[_token].fees.devStakeFee = configData.defaultStakeUnstakeFee;
        tokensData[_token].fees.devUnstakeFee = configData
            .defaultStakeUnstakeFee;
        tokensData[_token].admin = _msgSender();
        tokensData[_token].timestampAdded = block.timestamp;
        setTokenStakingApr(_token, _stakingApr);
        setTokenAdminStakeUnstakeFees(_token, _adminStakeFee, _adminUnstakeFee);
        setTokenRewardToken(
            _token,
            _reward_token == address(0x0) ? _token : _reward_token
        );
    }

    function activateToken(address _token) public onlyRole(_toRole(_token)) {
        require(tokenExists(_token), "Token does not exist.");
        tokensData[_token].isActive = true;
    }

    function deactivateToken(address _token) public onlyRole(_toRole(_token)) {
        require(tokenExists(_token), "Token does not exist.");
        tokensData[_token].isActive = false;
    }

    function excludeFromTokenAdminFees(address _token, address _address)
        public
        onlyRole(_toRole(_token))
    {
        isExcludedFromTokenAdminFees[_token][_address] = true;
    }

    function includeInTokenAdminFees(address _token, address _address)
        public
        onlyRole(_toRole(_token))
    {
        isExcludedFromTokenAdminFees[_token][_address] = false;
    }

    function setTokenName(address _token, string memory _name)
        public
        onlyRole(_toRole(_token))
    {
        require(tokenExists(_token), "Token does not exist.");
        tokensData[_token].name = _name;
        tokensData[_token].timestampLastUpdated = block.timestamp;
    }

    function setTokenCategory(address _token, uint256 _category)
        public
        onlyRole(_toRole(_token))
    {
        require(tokenExists(_token), "Token does not exist.");
        tokensData[_token].category = _category;
        tokensData[_token].timestampLastUpdated = block.timestamp;
    }

    function setTokenStakingApr(address _token, uint256 _stakingApr)
        public
        onlyRole(_toRole(_token))
    {
        require(tokenExists(_token), "Token does not exist.");
        require(
            _stakingApr >= configData.minimumStakingApr &&
                _stakingApr <= configData.maximumStakingApr,
            string.concat(
                "Staking APR must be between ",
                Strings.toString(_fromWei(configData.minimumStakingApr)),
                "% and ",
                Strings.toString(_fromWei(configData.maximumStakingApr)),
                "%."
            )
        );
        tokensData[_token].stakingApr = _stakingApr;
        tokensData[_token].timestampLastUpdated = block.timestamp;
    }

    function setTokenAdminStakeUnstakeFees(
        address _token,
        uint256 _adminStakeFee,
        uint256 _adminUnstakeFee
    ) public onlyRole(_toRole(_token)) {
        _setTokenStakeUnstakeFees(
            _token,
            _adminStakeFee,
            _adminUnstakeFee,
            "admin"
        );
    }

    function setTokenRewardToken(address _token, address _reward_token)
        public
        onlyRole(_toRole(_token))
        onlyRole(_toRole(_reward_token))
    {
        require(tokenExists(_token), "Token does not exist.");
        require(tokenExists(_reward_token), "Reward token does not exist.");
        tokensData[_token].rewardToken = _reward_token;
        tokensData[_token].timestampLastUpdated = block.timestamp;
    }

    function enableTokenMultiTokenRewards(address _token)
        public
        onlyRole(_toRole(_token))
    {
        require(tokenExists(_token), "Token does not exist.");
        require(tokensData[_token].isVerified, "Token not verified.");
        tokensData[_token].hasMultiTokenRewards = true;
    }

    function disableTokenMultiTokenRewards(address _token)
        public
        onlyRole(_toRole(_token))
    {
        require(tokenExists(_token), "Token does not exist.");
        tokensData[_token].hasMultiTokenRewards = false;
    }

    function depositToken(address _token, uint256 _amount)
        public
        onlyRole(_toRole(_token))
    {
        require(tokenExists(_token), "Token does not exist.");
        require(_amount > 0, "Amount must be greater than zero.");
        require(
            IERC20(_token).balanceOf(_msgSender()) >= _amount,
            "Insufficient wallet balance."
        );
        IERC20(_token).transferFrom(_msgSender(), address(this), _amount);
        tokensData[_token].rewardBalance += _amount;
    }

    function withdrawToken(address _token, uint256 _amount)
        public
        onlyRole(_toRole(_token))
    {
        require(tokenExists(_token), "Token does not exist.");
        require(_amount > 0, "Amount must be greater than zero.");
        require(
            tokensData[_token].rewardBalance >= _amount,
            "Insufficient reward balance."
        );
        tokensData[_token].rewardBalance -= _amount;
        IERC20(_token).transfer(_msgSender(), _amount);
    }

    function getTokenFeeAmounts(
        address _token,
        uint256 _amount,
        string memory _action
    ) public view returns (uint256, uint256) {
        require(tokenExists(_token), "Token does not exist.");
        require(_amount > 0, "Amount must be greater than zero.");

        uint256 devFee;
        uint256 devFeeAmount;
        uint256 adminFee;
        uint256 adminFeeAmount;
        if (
            keccak256(abi.encodePacked(_action)) ==
            keccak256(abi.encodePacked("deposit"))
        ) {} else if (
            keccak256(abi.encodePacked(_action)) ==
            keccak256(abi.encodePacked("withdraw"))
        ) {} else if (
            keccak256(abi.encodePacked(_action)) ==
            keccak256(abi.encodePacked("stake"))
        ) {
            devFee = tokensData[_token].fees.devStakeFee;
            devFeeAmount = _calculatePercentage(devFee, _amount);
            adminFee = tokensData[_token].fees.adminStakeFee;
            adminFeeAmount = _calculatePercentage(adminFee, _amount);
        } else if (
            keccak256(abi.encodePacked(_action)) ==
            keccak256(abi.encodePacked("unstake"))
        ) {
            devFee = tokensData[_token].fees.devUnstakeFee;
            devFeeAmount = _calculatePercentage(devFee, _amount);
            adminFee = tokensData[_token].fees.adminUnstakeFee;
            adminFeeAmount = _calculatePercentage(adminFee, _amount);
        }

        bool isExcludedFromFee = isExcludedFromFees[_msgSender()];
        bool isExcludedFromAdminFee = isExcludedFromTokenAdminFees[_token][
            _msgSender()
        ];
        if (isExcludedFromFee) {
            devFeeAmount = 0;
            adminFeeAmount = 0;
        } else if (isExcludedFromAdminFee) {
            adminFeeAmount = 0;
        }

        return (devFeeAmount, adminFeeAmount);
    }

    function _setTokenDepositWithdrawFees(
        address _token,
        uint256 _depositFee,
        uint256 _withdrawFee,
        string memory _for
    ) internal {
        require(tokenExists(_token), "Token does not exist.");
        require(
            _depositFee >= configData.minimumDepositWithdrawFee &&
                _depositFee <= configData.maximumDepositWithdrawFee,
            string.concat(
                "Deposit fee must be between ",
                Strings.toString(
                    _fromWei(configData.minimumDepositWithdrawFee)
                ),
                "% and ",
                Strings.toString(
                    _fromWei(configData.maximumDepositWithdrawFee)
                ),
                "%."
            )
        );
        require(
            _withdrawFee >= configData.minimumDepositWithdrawFee &&
                _withdrawFee <= configData.maximumDepositWithdrawFee,
            string.concat(
                "Withdraw fee must be between ",
                Strings.toString(
                    _fromWei(configData.minimumDepositWithdrawFee)
                ),
                "% and ",
                Strings.toString(
                    _fromWei(configData.maximumDepositWithdrawFee)
                ),
                "%."
            )
        );

        if (
            keccak256(abi.encodePacked(_for)) ==
            keccak256(abi.encodePacked("dev"))
        ) {
            tokensData[_token].fees.devDepositFee = _depositFee;
            tokensData[_token].fees.devWithdrawFee = _withdrawFee;
        } else if (
            keccak256(abi.encodePacked(_for)) ==
            keccak256(abi.encodePacked("admin"))
        ) {
            // tokensData[_token].fees.adminDepositFee = _depositFee;
            // tokensData[_token].fees.adminWithdrawFee = _withdrawFee;
        }
        tokensData[_token].timestampLastUpdated = block.timestamp;
    }

    function _setTokenStakeUnstakeFees(
        address _token,
        uint256 _stakeFee,
        uint256 _unstakeFee,
        string memory _for
    ) internal {
        require(tokenExists(_token), "Token does not exist.");
        require(
            _stakeFee >= configData.minimumStakeUnstakeFee &&
                _stakeFee <= configData.maximumStakeUnstakeFee,
            string.concat(
                "Stake fee must be between ",
                Strings.toString(_fromWei(configData.minimumStakeUnstakeFee)),
                "% and ",
                Strings.toString(_fromWei(configData.maximumStakeUnstakeFee)),
                "%."
            )
        );
        require(
            _unstakeFee >= configData.minimumStakeUnstakeFee &&
                _unstakeFee <= configData.maximumStakeUnstakeFee,
            string.concat(
                "Unstake fee must be between ",
                Strings.toString(_fromWei(configData.minimumStakeUnstakeFee)),
                "% and ",
                Strings.toString(_fromWei(configData.maximumStakeUnstakeFee)),
                "%."
            )
        );

        if (
            keccak256(abi.encodePacked(_for)) ==
            keccak256(abi.encodePacked("dev"))
        ) {
            tokensData[_token].fees.devStakeFee = _stakeFee;
            tokensData[_token].fees.devUnstakeFee = _unstakeFee;
        } else if (
            keccak256(abi.encodePacked(_for)) ==
            keccak256(abi.encodePacked("admin"))
        ) {
            tokensData[_token].fees.adminStakeFee = _stakeFee;
            tokensData[_token].fees.adminUnstakeFee = _unstakeFee;
        }
        tokensData[_token].timestampLastUpdated = block.timestamp;
    }

    function _toRole(address a) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(a));
    }
}
