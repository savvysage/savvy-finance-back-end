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
        uint256 dex;
        uint256 rewardBalance;
        uint256 stakingBalance;
        uint256 stakingApr;
        address rewardToken;
        address admin;
        TokenFeesDetails fees;
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

    function getTokenCategoryName(uint256 _number)
        public
        view
        returns (string memory)
    {
        return tokenCategory[_number];
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
                tokensData[_token].rewardBalance *
                    Lib.getTokenPrice(
                        address(this),
                        _token,
                        tokensData[_token].category
                    )
            );
    }

    function setTokenAdmin(address _token, address _admin) public onlyOwner {
        require(tokenExists(_token), "Token does not exist.");
        if (tokensData[_token].admin != owner())
            revokeRole(_toRole(_token), tokensData[_token].admin);
        tokensData[_token].admin = _admin;
        tokensData[_token].timestampLastUpdated = block.timestamp;
        grantRole(_toRole(_token), tokensData[_token].admin);
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
        uint256 _dex,
        uint256 _stakingApr,
        uint256 _adminStakeFee,
        uint256 _adminUnstakeFee,
        address _rewardToken
    ) public {
        require(!tokenExists(_token), "Token already exists.");
        _setupRole(_toRole(_token), owner());
        _setupRole(_toRole(_token), _msgSender());
        // uint256 index = tokens.length;
        tokens.push(_token);
        // tokensData[_token].index = index;
        tokensData[_token].category = _category;
        tokensData[_token].dex = _dex;
        tokensData[_token].admin = _msgSender();
        tokensData[_token].fees.devDepositFee = 1; // in wei
        tokensData[_token].fees.devWithdrawFee = 1; // in wei
        tokensData[_token].fees.devStakeFee = 1; // in wei
        tokensData[_token].fees.devUnstakeFee = 1; // in wei
        tokensData[_token].timestampAdded = block.timestamp;
        setTokenName(_token, _name);
        setTokenStakingApr(_token, _stakingApr);
        setTokenRewardToken(_token, _rewardToken);
        setTokenAdminStakeUnstakeFees(_token, _adminStakeFee, _adminUnstakeFee);
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
        require(
            bytes(_name).length >= configData.minimumTokenNameLength &&
                bytes(_name).length <= configData.maximumTokenNameLength,
            string.concat(
                "Token name length must be between ",
                Strings.toString(configData.minimumTokenNameLength),
                " and ",
                Strings.toString(configData.maximumTokenNameLength),
                "."
            )
        );
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

        (
            uint256 devDepositFeeAmount,
            uint256 adminDepositFeeAmount
        ) = getTokenFeeAmounts(_token, _amount, "deposit");
        if (devDepositFeeAmount != 0)
            IERC20(_token).transferFrom(
                _msgSender(),
                configData.developmentWallet,
                devDepositFeeAmount
            );
        uint256 depositAmount = _amount - devDepositFeeAmount;
        IERC20(_token).transferFrom(_msgSender(), address(this), depositAmount);
        tokensData[_token].rewardBalance += depositAmount;
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
        (
            uint256 devWithdrawFeeAmount,
            uint256 adminWithdrawFeeAmount
        ) = getTokenFeeAmounts(_token, _amount, "withdraw");
        if (devWithdrawFeeAmount != 0)
            IERC20(_token).transfer(
                configData.developmentWallet,
                devWithdrawFeeAmount
            );
        uint256 withdrawAmount = _amount - devWithdrawFeeAmount;
        IERC20(_token).transfer(_msgSender(), withdrawAmount);
    }

    function getTokenFeeAmounts(
        address _token,
        uint256 _amount,
        string memory _action
    ) public view returns (uint256, uint256) {
        require(tokenExists(_token), "Token does not exist.");
        require(_amount > 0, "Amount must be greater than zero.");

        uint256 devFee;
        uint256 adminFee;
        if (
            keccak256(abi.encodePacked(_action)) ==
            keccak256(abi.encodePacked("deposit"))
        ) {
            devFee = (tokensData[_token].fees.devDepositFee > 1) /* in wei */
                ? tokensData[_token].fees.devDepositFee
                : configData.defaultDepositWithdrawFee;
        } else if (
            keccak256(abi.encodePacked(_action)) ==
            keccak256(abi.encodePacked("withdraw"))
        ) {
            devFee = (tokensData[_token].fees.devWithdrawFee > 1) /* in wei */
                ? tokensData[_token].fees.devWithdrawFee
                : configData.defaultDepositWithdrawFee;
        } else if (
            keccak256(abi.encodePacked(_action)) ==
            keccak256(abi.encodePacked("stake"))
        ) {
            devFee = (tokensData[_token].fees.devStakeFee > 1) /* in wei */
                ? tokensData[_token].fees.devStakeFee
                : configData.defaultStakeUnstakeFee;
            adminFee = (tokensData[_token].fees.adminStakeFee > 1) /* in wei */
                ? tokensData[_token].fees.adminStakeFee
                : configData.defaultStakeUnstakeFee;
        } else if (
            keccak256(abi.encodePacked(_action)) ==
            keccak256(abi.encodePacked("unstake"))
        ) {
            devFee = (tokensData[_token].fees.devUnstakeFee > 1) /* in wei */
                ? tokensData[_token].fees.devUnstakeFee
                : configData.defaultStakeUnstakeFee;
            adminFee = (tokensData[_token].fees.adminUnstakeFee > 1) /* in wei */
                ? tokensData[_token].fees.adminUnstakeFee
                : configData.defaultStakeUnstakeFee;
        }

        uint256 devFeeAmount = _calculatePercentage(devFee, _amount);
        uint256 adminFeeAmount = _calculatePercentage(adminFee, _amount);
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
