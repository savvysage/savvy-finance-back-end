// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract SavvyFinanceFarm is Ownable, AccessControl {
    address constant ZERO_ADDRESS = 0x0000000000000000000000000000000000000000;
    mapping(address => bool) public isExcludedFromFees;
    mapping(uint256 => string) public tokenCategoryNumberToName;

    struct ConfigDetails {
        address developmentWallet;
        uint256 minimumTokenNameLength;
        uint256 maximumTokenNameLength;
        uint256 minimumStakingFee;
        uint256 maximumStakingFee;
        uint256 defaultStakingFee;
        uint256 minimumStakingApr;
        uint256 maximumStakingApr;
        uint256 defaultStakingApr;
    }
    ConfigDetails public configData;

    address[] public tokens;
    struct TokenStakingConfigDetails {
        uint256 stakeFee;
        uint256 unstakeFee;
        uint256 adminStakeFee;
        uint256 adminUnstakeFee;
        uint256 stakingApr;
    }
    struct TokenDetails {
        // uint256 index;
        bool isActive;
        bool isVerified;
        bool hasMultiReward;
        string name;
        uint256 category;
        uint256 price;
        uint256 rewardBalance;
        uint256 stakingBalance;
        TokenStakingConfigDetails stakingConfigData;
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
        address stakedToken;
        uint256 stakedTokenPrice;
        uint256 stakedTokenAmount;
        address rewardToken;
        uint256 rewardTokenPrice;
        uint256 rewardTokenAmount;
        uint256 stakingDurationInSeconds;
        string[2] actionPerformed;
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
    //     configData.minimumStakingFee = 0;
    //     configData.maximumStakingFee = toWei(10);
    //     configData.defaultStakingFee = toWei(1);
    //     configData.minimumStakingApr = toWei(50);
    //     configData.maximumStakingApr = toWei(1000);
    //     configData.defaultStakingApr = toWei(100);
    //     _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
    // }

    function initialize() external {
        configData.developmentWallet = _msgSender();
        configData.minimumStakingFee = 0;
        configData.maximumStakingFee = toWei(10);
        configData.defaultStakingFee = toWei(1);
        configData.minimumStakingApr = toWei(50);
        configData.maximumStakingApr = toWei(1000);
        configData.defaultStakingApr = toWei(100);
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _transferOwnership(_msgSender());
    }

    function toRole(address a) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(a));
    }

    function toWei(uint256 _number) public pure returns (uint256) {
        return _number * (10**18);
    }

    function fromWei(uint256 _number) public pure returns (uint256) {
        return _number / (10**18);
    }

    function secondsToYears(uint256 _seconds) public pure returns (uint256) {
        return fromWei(_seconds * (0.0000000317098 * (10**18)));
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

    function setDevelopmentWallet(address _developmentWallet) public onlyOwner {
        configData.developmentWallet = _developmentWallet;
    }

    function setStakingFeeConfig(
        uint256 _minimumStakingFee,
        uint256 _maximumStakingFee
    ) public onlyOwner {
        configData.minimumStakingFee = _minimumStakingFee;
        configData.maximumStakingFee = _maximumStakingFee;
    }

    function setStakingAprConfig(
        uint256 _minimumStakingApr,
        uint256 _maximumStakingApr
    ) public onlyOwner {
        configData.minimumStakingApr = _minimumStakingApr;
        configData.maximumStakingApr = _maximumStakingApr;
    }

    function excludeFromFees(address _address) public onlyOwner {
        isExcludedFromFees[_address] = true;
    }

    function includeInFees(address _address) public onlyOwner {
        isExcludedFromFees[_address] = false;
    }

    function setTokenCategoryNumberToName(uint256 _number, string memory _name)
        public
        onlyOwner
    {
        tokenCategoryNumberToName[_number] = _name;
    }

    function addToken(
        address _token,
        string memory _name,
        uint256 _category,
        uint256 _adminStakeFee,
        uint256 _adminUnstakeFee,
        uint256 _stakingApr,
        address _reward_token
    ) public {
        require(!tokenExists(_token), "Token already exists.");
        _setupRole(toRole(_token), owner());
        _setupRole(toRole(_token), _msgSender());
        // uint256 index = tokens.length;
        tokens.push(_token);
        // tokensData[_token].index = index;
        tokensData[_token].name = _name;
        tokensData[_token].category = _category;
        tokensData[_token].stakingConfigData.stakeFee = configData
            .defaultStakingFee;
        tokensData[_token].stakingConfigData.unstakeFee = configData
            .defaultStakingFee;
        tokensData[_token].admin = _msgSender();
        tokensData[_token].timestampAdded = block.timestamp;
        setTokenAdminStakingFees(
            _token,
            _adminStakeFee == 0 ? configData.defaultStakingFee : _adminStakeFee,
            _adminUnstakeFee == 0
                ? configData.defaultStakingFee
                : _adminUnstakeFee
        );
        setTokenStakingApr(
            _token,
            _stakingApr == 0 ? configData.defaultStakingApr : _stakingApr
        );
        setTokenRewardToken(
            _token,
            _reward_token == address(0x0) ? _token : _reward_token
        );
    }

    function verifyToken(address _token) public onlyOwner {
        require(tokenExists(_token), "Token does not exist.");
        tokensData[_token].isVerified = true;
    }

    function unverifyToken(address _token) public onlyOwner {
        require(tokenExists(_token), "Token does not exist.");
        tokensData[_token].isVerified = false;
    }

    function activateToken(address _token) public onlyOwner {
        require(tokenExists(_token), "Token does not exist.");
        tokensData[_token].isActive = true;
    }

    function deactivateToken(address _token) public onlyOwner {
        require(tokenExists(_token), "Token does not exist.");
        tokensData[_token].isActive = false;
    }

    function setTokenName(address _token, string memory _name)
        public
        onlyOwner
    {
        require(tokenExists(_token), "Token does not exist.");
        tokensData[_token].name = _name;
        tokensData[_token].timestampLastUpdated = block.timestamp;
    }

    function setTokenCategory(address _token, uint256 _category)
        public
        onlyOwner
    {
        require(tokenExists(_token), "Token does not exist.");
        tokensData[_token].category = _category;
        tokensData[_token].timestampLastUpdated = block.timestamp;
    }

    function setTokenPrice(address _token, uint256 _price) public onlyOwner {
        require(tokenExists(_token), "Token does not exist.");
        tokensData[_token].price = _price;
        tokensData[_token].timestampLastUpdated = block.timestamp;
    }

    function setTokenAdmin(address _token, address _admin) public onlyOwner {
        require(tokenExists(_token), "Token does not exist.");
        if (tokensData[_token].admin != owner())
            revokeRole(toRole(_token), tokensData[_token].admin);
        tokensData[_token].admin = _admin;
        tokensData[_token].timestampLastUpdated = block.timestamp;
        grantRole(toRole(_token), tokensData[_token].admin);
    }

    function setTokenStakingFees(
        address _token,
        uint256 _stakeFee,
        uint256 _unstakeFee
    ) public onlyOwner {
        setTokenStakeFee(_token, _stakeFee, false);
        setTokenUnstakeFee(_token, _unstakeFee, false);
    }

    function setTokenAdminStakingFees(
        address _token,
        uint256 _stakeFee,
        uint256 _unstakeFee
    ) public onlyRole(toRole(_token)) {
        setTokenStakeFee(_token, _stakeFee, true);
        setTokenUnstakeFee(_token, _unstakeFee, true);
    }

    function setTokenStakeFee(
        address _token,
        uint256 _stakeFee,
        bool forAdmin
    ) internal {
        require(tokenExists(_token), "Token does not exist.");
        require(
            _stakeFee >= configData.minimumStakingFee &&
                _stakeFee <= configData.maximumStakingFee,
            string(
                abi.encodePacked(
                    "Stake fee must be between",
                    fromWei(configData.minimumStakingFee),
                    "and",
                    fromWei(configData.maximumStakingFee),
                    "."
                )
            )
        );

        if (forAdmin)
            tokensData[_token].stakingConfigData.adminStakeFee = _stakeFee;
        else tokensData[_token].stakingConfigData.stakeFee = _stakeFee;
        tokensData[_token].timestampLastUpdated = block.timestamp;
    }

    function setTokenUnstakeFee(
        address _token,
        uint256 _unstakeFee,
        bool forAdmin
    ) internal {
        require(tokenExists(_token), "Token does not exist.");
        require(
            _unstakeFee >= configData.minimumStakingFee &&
                _unstakeFee <= configData.maximumStakingFee,
            string(
                abi.encodePacked(
                    "Unstake fee must be between",
                    fromWei(configData.minimumStakingFee),
                    "and",
                    fromWei(configData.maximumStakingFee),
                    "."
                )
            )
        );

        if (forAdmin)
            tokensData[_token].stakingConfigData.adminUnstakeFee = _unstakeFee;
        else tokensData[_token].stakingConfigData.unstakeFee = _unstakeFee;
        tokensData[_token].timestampLastUpdated = block.timestamp;
    }

    function setTokenStakingApr(address _token, uint256 _stakingApr)
        public
        onlyRole(toRole(_token))
    {
        require(tokenExists(_token), "Token does not exist.");
        require(
            _stakingApr >= configData.minimumStakingApr &&
                _stakingApr <= configData.maximumStakingApr,
            string(
                abi.encodePacked(
                    "Staking APR must be between",
                    fromWei(configData.minimumStakingApr),
                    "and",
                    fromWei(configData.maximumStakingApr),
                    "."
                )
            )
        );
        tokensData[_token].stakingConfigData.stakingApr = _stakingApr;
        tokensData[_token].timestampLastUpdated = block.timestamp;
    }

    function setTokenRewardToken(address _token, address _reward_token)
        public
        onlyRole(toRole(_token))
        onlyRole(toRole(_reward_token))
    {
        require(tokenExists(_token), "Token does not exist.");
        require(tokenExists(_reward_token), "Reward token does not exist.");
        tokensData[_token].rewardToken = _reward_token;
        tokensData[_token].timestampLastUpdated = block.timestamp;
    }

    function enableTokenMultiReward(address _token)
        public
        onlyRole(toRole(_token))
    {
        require(tokenExists(_token), "Token does not exist.");
        tokensData[_token].hasMultiReward = true;
    }

    function disableTokenMultiReward(address _token)
        public
        onlyRole(toRole(_token))
    {
        require(tokenExists(_token), "Token does not exist.");
        tokensData[_token].hasMultiReward = false;
    }

    function depositToken(address _token, uint256 _amount)
        public
        onlyRole(toRole(_token))
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
        onlyRole(toRole(_token))
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

    function addStaker(address _staker) internal {
        require(!stakerExists(_staker), "Staker already exists.");
        // uint256 index = stakers.length;
        stakers.push(_staker);
        // stakersData[_staker].index = index;
        stakersData[_staker].timestampAdded = block.timestamp;
    }

    function stakeToken(address _token, uint256 _amount) public {
        require(tokensData[_token].isActive, "Token not active.");
        require(_amount > 0, "Amount must be greater than zero.");
        require(
            IERC20(_token).balanceOf(_msgSender()) >= _amount,
            "Insufficient wallet balance."
        );

        uint256 stakeFeeAmount = (_amount / toWei(100)) *
            tokensData[_token].stakingConfigData.stakeFee;
        uint256 adminStakeFeeAmount = (_amount / toWei(100)) *
            tokensData[_token].stakingConfigData.adminStakeFee;
        uint256 totalStakeFeeAmount = stakeFeeAmount + adminStakeFeeAmount;

        uint256 stakeAmount;
        if (totalStakeFeeAmount == 0 || isExcludedFromFees[_msgSender()]) {
            stakeAmount = _amount;
        } else {
            IERC20(_token).transferFrom(
                _msgSender(),
                configData.developmentWallet,
                stakeFeeAmount
            );
            IERC20(_token).transferFrom(
                _msgSender(),
                tokensData[_token].admin,
                adminStakeFeeAmount
            );
            stakeAmount = _amount - totalStakeFeeAmount;
        }
        IERC20(_token).transferFrom(_msgSender(), address(this), stakeAmount);

        if (tokensStakersData[_token][_msgSender()].stakingBalance == 0) {
            if (stakersData[_msgSender()].uniqueTokensStaked == 0) {
                if (!stakerExists(_msgSender())) addStaker(_msgSender());
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
            issueStakingReward(
                _token,
                _msgSender(),
                ["stake", Strings.toString(fromWei(_amount))]
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

        issueStakingReward(
            _token,
            _msgSender(),
            ["unstake", Strings.toString(fromWei(_amount))]
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

        uint256 unstakeFeeAmount = (_amount / toWei(100)) *
            tokensData[_token].stakingConfigData.unstakeFee;
        uint256 adminUnstakeFeeAmount = (_amount / toWei(100)) *
            tokensData[_token].stakingConfigData.adminUnstakeFee;
        uint256 totalUnstakeFeeAmount = unstakeFeeAmount +
            adminUnstakeFeeAmount;

        uint256 unstakeAmount;
        if (totalUnstakeFeeAmount == 0 || isExcludedFromFees[_msgSender()]) {
            unstakeAmount = _amount;
        } else {
            IERC20(_token).transfer(
                configData.developmentWallet,
                unstakeFeeAmount
            );
            IERC20(_token).transfer(
                tokensData[_token].admin,
                adminUnstakeFeeAmount
            );
            unstakeAmount = _amount - totalUnstakeFeeAmount;
        }
        IERC20(_token).transfer(_msgSender(), unstakeAmount);
        emit Unstake(_msgSender(), _token, unstakeAmount);
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

    function setStakingRewardToken(address _token, address _reward_token)
        public
    {
        setStakerStakingRewardToken(_msgSender(), _token, _reward_token, true);
    }

    function setStakerStakingRewardToken(
        address _staker,
        address _token,
        address _reward_token,
        bool validate
    ) internal returns (address) {
        if (validate) {
            require(tokensData[_token].isActive, "Token not active.");
            require(
                tokensData[_token].hasMultiReward,
                "Token does not have multi reward."
            );
            require(
                tokensData[_reward_token].isActive,
                "Reward token not active."
            );
            require(
                tokensData[_reward_token].hasMultiReward,
                "Reward token does not have multi reward."
            );
        }

        if (!stakerExists(_staker)) addStaker(_staker);
        tokensStakersData[_token][_staker].stakingRewardToken = _reward_token;
        return tokensStakersData[_token][_staker].stakingRewardToken;
    }

    function calculateStakerStakingRewardValue(address _staker, address _token)
        internal
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        if (!stakerExists(_staker)) return (0, 0, 0, 0);
        if (!tokenExists(_token)) return (0, 0, 0, 0);

        TokenDetails memory tokenData = tokensData[_token];
        TokenStakerDetails memory tokenStakerData = tokensStakersData[_token][
            _staker
        ];
        if (tokenStakerData.stakingBalance <= 0) return (0, 0, 0, 0);

        uint256 stakingValue = fromWei(
            tokenStakerData.stakingBalance * tokenData.price
        );
        uint256 rate = tokenData.stakingConfigData.stakingApr / 100;
        uint256 stakingTimestampStarted = tokenStakerData
            .timestampLastRewarded != 0
            ? tokenStakerData.timestampLastRewarded
            : tokenStakerData.timestampAdded;
        uint256 stakingTimestampEnded = block.timestamp;
        uint256 stakingDurationInSeconds = toWei(
            stakingTimestampEnded - stakingTimestampStarted
        );
        uint256 stakingDurationInYears = secondsToYears(
            stakingDurationInSeconds
        );
        uint256 stakingRewardValue = (stakingValue *
            rate *
            stakingDurationInYears) / (10**36);

        return (
            stakingRewardValue,
            stakingDurationInSeconds,
            tokenStakerData.stakingBalance,
            tokenData.price
        );
    }

    function issueStakingReward(
        address _token,
        address _staker,
        string[2] memory _actionPerformed
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
            tokenStakerData.stakingRewardToken = setStakerStakingRewardToken(
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
            uint256 stakingBalance,
            uint256 tokenPrice
        ) = calculateStakerStakingRewardValue(_staker, _token);
        if (stakingRewardValue == 0) return;

        uint256 stakerRewardTokenRewardValue = getTokenRewardValue(
            tokenStakerData.stakingRewardToken
        );
        if (stakerRewardTokenRewardValue < stakingRewardValue) {
            if (tokenStakerData.stakingRewardToken == tokenData.rewardToken) {
                deactivateToken(_token);
                return;
            }
            tokenStakerData.stakingRewardToken = setStakerStakingRewardToken(
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
        uint256 stakingRewardTokenAmount = toWei(stakingRewardValue) /
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
        tokenStakerRewardData.stakedToken = _token;
        tokenStakerRewardData.stakedTokenPrice = tokenPrice;
        tokenStakerRewardData.stakedTokenAmount = tokenStakerData
            .stakingBalance;
        tokenStakerRewardData.rewardToken = tokenStakerData.stakingRewardToken;
        tokenStakerRewardData.rewardTokenPrice = stakingRewardTokenPrice;
        tokenStakerRewardData.rewardTokenAmount = stakingRewardTokenAmount;
        tokenStakerRewardData
            .stakingDurationInSeconds = stakingDurationInSeconds;
        tokenStakerRewardData.actionPerformed = _actionPerformed;
        tokenStakerRewardData.timestampAdded = block.timestamp;
        tokensStakersData[_token][_staker].stakingRewards.push(
            tokenStakerRewardData
        );

        emit IssueStakingReward(_staker, _token, tokenStakerRewardData);
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

                issueStakingReward(
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
}
