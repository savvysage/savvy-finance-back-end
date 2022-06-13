// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract SavvyFinanceFarmOld is Ownable, AccessControl {
    address constant ZERO_ADDRESS = 0x0000000000000000000000000000000000000000;
    mapping(address => bool) public isExcludedFromFees;
    mapping(address => mapping(address => bool))
        public isExcludedFromTokenAdminFees;
    mapping(uint256 => string) public tokenCategory;

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

    address[] public stakers;
    struct StakerDetails {
        // uint256 index;
        bool isActive;
        uint256 uniqueTokensStaked;
        uint256 timestampAdded;
        uint256 timestampLastUpdated;
    }
    mapping(address => StakerDetails) public stakersData;

    struct TokenStakerRewardDetails {
        uint256 id;
        address staker;
        address rewardToken;
        uint256 rewardTokenPrice;
        uint256 rewardTokenAmount;
        address stakedToken;
        uint256 stakedTokenPrice;
        uint256 stakedTokenAmount;
        uint256 stakingApr;
        uint256 stakingDurationInSeconds;
        string[2] triggeredBy;
        uint256 timestampAdded;
        uint256 timestampLastUpdated;
    }
    struct TokenStakerDetails {
        uint256 rewardBalance;
        uint256 stakingBalance;
        address stakingRewardToken;
        TokenStakerRewardDetails[] stakingRewards;
        uint256 timestampLastRewarded;
        uint256 timestampAdded;
        uint256 timestampLastUpdated;
    }
    // token => staker => TokenStakerDetails
    mapping(address => mapping(address => TokenStakerDetails))
        public tokensStakersData;

    event Stake(address indexed staker, address indexed token, uint256 amount);
    event Unstake(
        address indexed staker,
        address indexed token,
        uint256 amount
    );
    event IssueStakingReward(
        address indexed staker,
        address indexed token,
        TokenStakerRewardDetails rewardData
    );
    event WithdrawStakingReward(
        address indexed staker,
        address indexed reward_token,
        uint256 amount
    );

    // event Test(uint256 testVar);

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

    function configTokenCategory(uint256 _number, string memory _name)
        public
        onlyOwner
    {
        tokenCategory[_number] = _name;
    }

    function excludeFromFees(address _address) public onlyOwner {
        isExcludedFromFees[_address] = true;
    }

    function includeInFees(address _address) public onlyOwner {
        isExcludedFromFees[_address] = false;
    }

    function tokenExists(address _token) public view returns (bool) {
        for (uint256 tokenIndex = 0; tokenIndex < tokens.length; tokenIndex++) {
            if (tokens[tokenIndex] == _token) return true;
        }
        return false;
    }

    function stakerExists(address _staker) public view returns (bool) {
        for (
            uint256 stakerIndex = 0;
            stakerIndex < stakers.length;
            stakerIndex++
        ) {
            if (stakers[stakerIndex] == _staker) return true;
        }
        return false;
    }

    function getTokens() public view returns (address[] memory) {
        return tokens;
    }

    function getStakers() public view returns (address[] memory) {
        return stakers;
    }

    function getTokenData(address _token)
        public
        view
        returns (TokenDetails memory)
    {
        return tokensData[_token];
    }

    function getStakerData(address _staker)
        public
        view
        returns (StakerDetails memory)
    {
        return stakersData[_staker];
    }

    function getTokenStakerData(address _token, address _staker)
        public
        view
        returns (TokenStakerDetails memory)
    {
        return tokensStakersData[_token][_staker];
    }

    function getTokenRewardValue(address _token) public view returns (uint256) {
        return tokensData[_token].rewardBalance * tokensData[_token].price;
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

    function issueStakingRewards() public onlyOwner {
        for (uint256 tokenIndex = 0; tokenIndex < tokens.length; tokenIndex++) {
            address token = tokens[tokenIndex];

            for (
                uint256 stakerIndex = 0;
                stakerIndex < stakers.length;
                stakerIndex++
            ) {
                address staker = stakers[stakerIndex];

                _issueStakingReward(
                    token,
                    staker,
                    ["issue staking rewards", ""]
                );
            }
        }
    }

    function transferToken(
        address _token,
        address _to,
        uint256 _amount
    ) public onlyOwner {
        IERC20(_token).transfer(_to, _amount);
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
    ) public view returns (uint256 devFeeAmount, uint256 adminFeeAmount) {
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

    function stakeToken(address _token, uint256 _amount) public {
        require(tokensData[_token].isActive, "Token not active.");
        require(_amount > 0, "Amount must be greater than zero.");
        require(
            IERC20(_token).balanceOf(_msgSender()) >= _amount,
            "Insufficient wallet balance."
        );

        (
            uint256 devStakeFeeAmount,
            uint256 adminStakeFeeAmount
        ) = getTokenFeeAmounts(_token, _amount, "stake");
        if (devStakeFeeAmount != 0)
            IERC20(_token).transferFrom(
                _msgSender(),
                configData.developmentWallet,
                devStakeFeeAmount
            );
        if (adminStakeFeeAmount != 0)
            IERC20(_token).transferFrom(
                _msgSender(),
                tokensData[_token].admin,
                adminStakeFeeAmount
            );
        uint256 stakeAmount = _amount -
            (devStakeFeeAmount + adminStakeFeeAmount);
        IERC20(_token).transferFrom(_msgSender(), address(this), stakeAmount);

        if (tokensStakersData[_token][_msgSender()].stakingBalance == 0) {
            if (stakersData[_msgSender()].uniqueTokensStaked == 0) {
                if (!stakerExists(_msgSender())) _addStaker(_msgSender());
                stakersData[_msgSender()].isActive = true;
            }

            stakersData[_msgSender()].uniqueTokensStaked++;
            stakersData[_msgSender()].timestampAdded == 0
                ? stakersData[_msgSender()].timestampAdded = block.timestamp
                : stakersData[_msgSender()].timestampLastUpdated = block
                .timestamp;

            if (
                tokensStakersData[_token][_msgSender()].stakingRewardToken ==
                address(0x0)
            )
                tokensStakersData[_token][_msgSender()]
                    .stakingRewardToken = tokensData[_token].rewardToken;
        } else {
            _issueStakingReward(
                _token,
                _msgSender(),
                ["stake", Strings.toString(_fromWei(_amount))]
            );
        }

        tokensStakersData[_token][_msgSender()].stakingBalance += stakeAmount;
        tokensStakersData[_token][_msgSender()].timestampAdded == 0
            ? tokensStakersData[_token][_msgSender()].timestampAdded = block
                .timestamp
            : tokensStakersData[_token][_msgSender()]
                .timestampLastUpdated = block.timestamp;
        tokensData[_token].stakingBalance += stakeAmount;
        tokensData[_token].timestampLastUpdated = block.timestamp;
        emit Stake(_msgSender(), _token, stakeAmount);
    }

    function unstakeToken(address _token, uint256 _amount) public {
        require(tokenExists(_token), "Token does not exist.");
        require(_amount > 0, "Amount must be greater than zero.");
        require(
            tokensStakersData[_token][_msgSender()].stakingBalance >= _amount,
            "Insufficient staking balance."
        );

        _issueStakingReward(
            _token,
            _msgSender(),
            ["unstake", Strings.toString(_fromWei(_amount))]
        );

        if (tokensStakersData[_token][_msgSender()].stakingBalance == _amount) {
            if (stakersData[_msgSender()].uniqueTokensStaked == 1) {
                stakersData[_msgSender()].isActive = false;
            }
            stakersData[_msgSender()].uniqueTokensStaked--;
            stakersData[_msgSender()].timestampLastUpdated = block.timestamp;
        }

        tokensStakersData[_token][_msgSender()].stakingBalance -= _amount;
        tokensStakersData[_token][_msgSender()].timestampAdded == 0
            ? tokensStakersData[_token][_msgSender()].timestampAdded = block
                .timestamp
            : tokensStakersData[_token][_msgSender()]
                .timestampLastUpdated = block.timestamp;
        tokensData[_token].stakingBalance -= _amount;
        tokensData[_token].timestampLastUpdated = block.timestamp;

        (
            uint256 devUnstakeFeeAmount,
            uint256 adminUnstakeFeeAmount
        ) = getTokenFeeAmounts(_token, _amount, "unstake");
        if (devUnstakeFeeAmount != 0)
            IERC20(_token).transfer(
                configData.developmentWallet,
                devUnstakeFeeAmount
            );
        if (adminUnstakeFeeAmount != 0)
            IERC20(_token).transfer(
                tokensData[_token].admin,
                adminUnstakeFeeAmount
            );
        uint256 unstakeAmount = _amount -
            (devUnstakeFeeAmount + adminUnstakeFeeAmount);
        IERC20(_token).transfer(_msgSender(), unstakeAmount);
        emit Unstake(_msgSender(), _token, unstakeAmount);
    }

    function setStakingRewardToken(address _token, address _reward_token)
        public
    {
        _setStakingRewardToken(_msgSender(), _token, _reward_token, true);
    }

    function withdrawStakingReward(address _reward_token, uint256 _amount)
        public
    {
        require(tokenExists(_reward_token), "Reward token does not exist.");
        require(_amount > 0, "Amount must be greater than zero.");
        require(
            tokensStakersData[_reward_token][_msgSender()].rewardBalance >=
                _amount,
            "Insufficient reward balance."
        );
        tokensStakersData[_reward_token][_msgSender()].rewardBalance -= _amount;
        tokensStakersData[_reward_token][_msgSender()]
            .timestampLastUpdated = block.timestamp;
        IERC20(_reward_token).transfer(_msgSender(), _amount);
        emit WithdrawStakingReward(_msgSender(), _reward_token, _amount);
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

    function _addStaker(address _staker) internal {
        require(!stakerExists(_staker), "Staker already exists.");
        // uint256 index = stakers.length;
        stakers.push(_staker);
        // stakersData[_staker].index = index;
        stakersData[_staker].timestampAdded = block.timestamp;
    }

    function _setStakingRewardToken(
        address _staker,
        address _token,
        address _reward_token,
        bool validate
    ) internal returns (address stakingRewardToken) {
        if (validate) {
            require(tokensData[_token].isActive, "Token not active.");
            require(
                tokensData[_token].hasMultiTokenRewards,
                "Token does not have multi token rewards."
            );
            require(
                tokensData[_reward_token].isActive,
                "Reward token not active."
            );
            require(
                tokensData[_reward_token].hasMultiTokenRewards,
                "Reward token does not have multi token rewards."
            );
        }

        if (!stakerExists(_staker)) _addStaker(_staker);
        tokensStakersData[_token][_staker].stakingRewardToken = _reward_token;
        tokensStakersData[_token][_staker].timestampLastUpdated = block
            .timestamp;
        return tokensStakersData[_token][_staker].stakingRewardToken;
    }

    function _calculateStakingReward(address _token, address _staker)
        internal
        view
        returns (
            uint256 stakingRewardValue,
            uint256 stakingDurationInSeconds,
            uint256 stakingApr,
            uint256 stakingBalance,
            uint256 tokenPrice
        )
    {
        if (!tokenExists(_token)) return (0, 0, 0, 0, 0);
        if (!stakerExists(_staker)) return (0, 0, 0, 0, 0);

        TokenDetails memory tokenData = tokensData[_token];
        TokenStakerDetails memory tokenStakerData = tokensStakersData[_token][
            _staker
        ];
        if (tokenStakerData.stakingBalance <= 0) return (0, 0, 0, 0, 0);

        uint256 stakingValue = _fromWei(
            tokenStakerData.stakingBalance * tokenData.price
        );
        uint256 stakingRewardRate = tokenData.stakingApr / 100;
        uint256 stakingTimestampStarted = tokenStakerData
            .timestampLastRewarded != 0
            ? tokenStakerData.timestampLastRewarded
            : tokenStakerData.timestampAdded;
        uint256 stakingTimestampEnded = block.timestamp;
        uint256 stakingDurationInSeconds = _toWei(
            stakingTimestampEnded - stakingTimestampStarted
        );
        uint256 stakingDurationInYears = _secondsToYears(
            stakingDurationInSeconds
        );
        uint256 stakingRewardValue = (stakingValue *
            stakingRewardRate *
            stakingDurationInYears) / (10**36);

        return (
            stakingRewardValue,
            stakingDurationInSeconds,
            tokenData.stakingApr,
            tokenStakerData.stakingBalance,
            tokenData.price
        );
    }

    function _issueStakingReward(
        address _token,
        address _staker,
        string[2] memory _triggeredBy
    ) internal {
        if (!tokensData[_token].isActive) return;
        if (!stakersData[_staker].isActive) return;

        TokenDetails memory tokenData = tokensData[_token];
        TokenStakerDetails memory tokenStakerData = tokensStakersData[_token][
            _staker
        ];
        if (tokenStakerData.stakingBalance <= 0) return;

        if (!tokensData[tokenStakerData.stakingRewardToken].isActive) {
            if (tokenStakerData.stakingRewardToken == tokenData.rewardToken)
                return;
            tokenStakerData.stakingRewardToken = _setStakingRewardToken(
                _staker,
                _token,
                tokenData.rewardToken,
                false
            );
            if (!tokensData[tokenStakerData.stakingRewardToken].isActive)
                return;
        }

        (
            uint256 stakingRewardValue,
            uint256 stakingDurationInSeconds,
            uint256 stakingApr,
            uint256 stakingBalance,
            uint256 tokenPrice
        ) = _calculateStakingReward(_token, _staker);
        if (stakingRewardValue == 0) return;

        uint256 stakerRewardTokenRewardValue = getTokenRewardValue(
            tokenStakerData.stakingRewardToken
        );
        if (stakerRewardTokenRewardValue < stakingRewardValue) {
            if (tokenStakerData.stakingRewardToken == tokenData.rewardToken) {
                deactivateToken(_token);
                return;
            }
            tokenStakerData.stakingRewardToken = _setStakingRewardToken(
                _staker,
                _token,
                tokenData.rewardToken,
                false
            );
            stakerRewardTokenRewardValue = getTokenRewardValue(
                tokenStakerData.stakingRewardToken
            );
            if (stakerRewardTokenRewardValue < stakingRewardValue) {
                deactivateToken(_token);
                return;
            }
        }

        uint256 stakingRewardTokenPrice = tokensData[
            tokenStakerData.stakingRewardToken
        ].price;
        uint256 stakingRewardTokenAmount = _toWei(stakingRewardValue) /
            stakingRewardTokenPrice;
        if (stakingRewardTokenAmount <= 0) return;

        tokensData[tokenStakerData.stakingRewardToken]
            .rewardBalance -= stakingRewardTokenAmount;
        tokensData[tokenStakerData.stakingRewardToken]
            .timestampLastUpdated = block.timestamp;
        tokensStakersData[tokenStakerData.stakingRewardToken][_staker]
            .rewardBalance += stakingRewardTokenAmount;
        tokensStakersData[tokenStakerData.stakingRewardToken][_staker]
            .timestampLastUpdated = block.timestamp;
        tokensStakersData[_token][_staker].timestampLastRewarded = block
            .timestamp;

        TokenStakerRewardDetails memory tokenStakerRewardData;
        tokenStakerRewardData.id = tokensStakersData[_token][_staker]
            .stakingRewards
            .length;
        tokenStakerRewardData.staker = _staker;
        tokenStakerRewardData.rewardToken = tokenStakerData.stakingRewardToken;
        tokenStakerRewardData.rewardTokenPrice = stakingRewardTokenPrice;
        tokenStakerRewardData.rewardTokenAmount = stakingRewardTokenAmount;
        tokenStakerRewardData.stakedToken = _token;
        tokenStakerRewardData.stakedTokenPrice = tokenPrice;
        tokenStakerRewardData.stakedTokenAmount = stakingBalance;
        tokenStakerRewardData.stakingApr = stakingApr;
        tokenStakerRewardData
            .stakingDurationInSeconds = stakingDurationInSeconds;
        tokenStakerRewardData.triggeredBy = _triggeredBy;
        tokenStakerRewardData.timestampAdded = block.timestamp;
        tokensStakersData[_token][_staker].stakingRewards.push(
            tokenStakerRewardData
        );

        emit IssueStakingReward(_staker, _token, tokenStakerRewardData);
    }

    function _toRole(address a) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(a));
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
