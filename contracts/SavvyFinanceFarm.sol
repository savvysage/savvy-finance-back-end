// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract SavvyFinanceFarm is Ownable, AccessControl {
    address constant ZERO_ADDRESS = 0x0000000000000000000000000000000000000000;
    address public developmentWallet;
    uint256 public minimumStakingFee;
    uint256 public maximumStakingFee;
    uint256 public minimumStakingApr;
    uint256 public maximumStakingApr;
    mapping(address => bool) public isExcludedFromFees;
    mapping(uint256 => string) public tokenTypeNumberToName;

    address[] public tokens;
    struct TokenDetails {
        // uint256 index;
        bool isActive;
        bool hasMultiReward;
        string name;
        uint256 _type;
        uint256 price;
        uint256 rewardBalance;
        uint256 stakingBalance;
        uint256 stakeFee;
        uint256 unstakeFee;
        uint256 stakingApr;
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
    event WithdrawStakingReward(
        address indexed staker,
        address indexed reward_token,
        uint256 amount
    );

    // constructor() {
    //     developmentWallet = _msgSender();
    //     minimumStakingFee = 0;
    //     maximumStakingFee = toWei(10);
    //     minimumStakingApr = toWei(50);
    //     maximumStakingApr = toWei(1000);
    //     _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
    // }

    function initialize() external {
        developmentWallet = _msgSender();
        minimumStakingFee = 0;
        maximumStakingFee = toWei(10);
        minimumStakingApr = toWei(50);
        maximumStakingApr = toWei(1000);
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

    function getTokenValue(address _token) public view returns (uint256) {
        return tokensData[_token].rewardBalance * tokensData[_token].price;
    }

    function setDevelopmentWallet(address _developmentWallet) public onlyOwner {
        developmentWallet = _developmentWallet;
    }

    function setStakingFeeDetails(
        uint256 _minimumStakingFee,
        uint256 _maximumStakingFee
    ) public onlyOwner {
        minimumStakingFee = _minimumStakingFee;
        maximumStakingFee = _maximumStakingFee;
    }

    function setStakingAprDetails(
        uint256 _minimumStakingApr,
        uint256 _maximumStakingApr
    ) public onlyOwner {
        minimumStakingApr = _minimumStakingApr;
        maximumStakingApr = _maximumStakingApr;
    }

    function excludeFromFees(address _address) public onlyOwner {
        isExcludedFromFees[_address] = true;
    }

    function includeInFees(address _address) public onlyOwner {
        isExcludedFromFees[_address] = false;
    }

    function setTokenTypeNumberToName(uint256 _number, string memory _name)
        public
        onlyOwner
    {
        tokenTypeNumberToName[_number] = _name;
    }

    function addToken(
        address _token,
        string memory _name,
        uint256 _type,
        uint256 _stakeFee,
        uint256 _unstakeFee,
        uint256 _stakingApr,
        address _reward_token,
        address _admin
    ) public onlyOwner {
        require(!tokenExists(_token), "Token already exists.");
        _setupRole(toRole(_token), _msgSender());
        uint256 index = tokens.length;
        tokens.push(_token);
        // tokensData[_token].index = index;
        tokensData[_token].name = _name;
        tokensData[_token]._type = _type;
        tokensData[_token].timestampAdded = block.timestamp;
        setTokenStakingFees(
            _token,
            _stakeFee == 0 ? toWei(1) : _stakeFee,
            _unstakeFee == 0 ? toWei(1) : _unstakeFee
        );
        setTokenStakingApr(_token, _stakingApr == 0 ? toWei(365) : _stakingApr);
        setTokenRewardToken(
            _token,
            _reward_token == address(0x0) ? _token : _reward_token
        );
        setTokenAdmin(_token, _admin == address(0x0) ? _msgSender() : _admin);
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

    function setTokenType(address _token, uint256 _type) public onlyOwner {
        require(tokenExists(_token), "Token does not exist.");
        tokensData[_token]._type = _type;
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
        setTokenStakeFee(_token, _stakeFee);
        setTokenUnstakeFee(_token, _unstakeFee);
    }

    function setTokenStakeFee(address _token, uint256 _stakeFee)
        public
        onlyOwner
    {
        require(tokenExists(_token), "Token does not exist.");
        require(
            _stakeFee >= minimumStakingFee && _stakeFee <= maximumStakingFee,
            string(
                abi.encodePacked(
                    "Stake fee must be between",
                    fromWei(minimumStakingFee),
                    "and",
                    fromWei(maximumStakingFee),
                    "."
                )
            )
        );
        tokensData[_token].stakeFee = _stakeFee;
        tokensData[_token].timestampLastUpdated = block.timestamp;
    }

    function setTokenUnstakeFee(address _token, uint256 _unstakeFee)
        public
        onlyOwner
    {
        require(tokenExists(_token), "Token does not exist.");
        require(
            _unstakeFee >= minimumStakingFee &&
                _unstakeFee <= maximumStakingFee,
            string(
                abi.encodePacked(
                    "Unstake fee must be between",
                    fromWei(minimumStakingFee),
                    "and",
                    fromWei(maximumStakingFee),
                    "."
                )
            )
        );
        tokensData[_token].unstakeFee = _unstakeFee;
        tokensData[_token].timestampLastUpdated = block.timestamp;
    }

    function setTokenStakingApr(address _token, uint256 _stakingApr)
        public
        onlyRole(toRole(_token))
    {
        require(tokenExists(_token), "Token does not exist.");
        require(
            _stakingApr >= minimumStakingApr &&
                _stakingApr <= maximumStakingApr,
            string(
                abi.encodePacked(
                    "Staking APR must be between",
                    fromWei(minimumStakingApr),
                    "and",
                    fromWei(maximumStakingApr),
                    "."
                )
            )
        );
        tokensData[_token].stakingApr = _stakingApr;
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

    function depositToken(address _token, uint256 _amount)
        public
        onlyRole(toRole(_token))
    {
        require(tokenExists(_token), "Token does not exist.");
        require(_amount > 0, "Amount must be greater than zero.");
        require(
            IERC20(_token).balanceOf(_msgSender()) >= _amount,
            "Insufficient token balance."
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
            "Amount is greater than token reward balance."
        );
        tokensData[_token].rewardBalance -= _amount;
        IERC20(_token).transfer(_msgSender(), _amount);
    }

    function stakeToken(address _token, uint256 _amount) public {
        require(tokensData[_token].isActive, "Token not active.");
        require(_amount > 0, "Amount must be greater than zero.");
        require(
            IERC20(_token).balanceOf(_msgSender()) >= _amount,
            "Insufficient token balance."
        );

        uint256 stakeFee = (_amount / toWei(100)) * tokensData[_token].stakeFee;
        uint256 stakeAmount;
        if (stakeFee == 0 || isExcludedFromFees[_msgSender()]) {
            stakeAmount = _amount;
        } else {
            IERC20(_token).transferFrom(
                _msgSender(),
                developmentWallet,
                stakeFee
            );
            stakeAmount = _amount - stakeFee;
        }
        IERC20(_token).transferFrom(_msgSender(), address(this), stakeAmount);

        if (tokensStakersData[_token][_msgSender()].stakingBalance == 0) {
            if (stakersData[_msgSender()].uniqueTokensStaked == 0) {
                if (!stakerExists(_msgSender())) {
                    uint256 index = stakers.length;
                    stakers.push(_msgSender());
                    // stakersData[_msgSender()].index = index;
                }
                stakersData[_msgSender()].isActive = true;
            }

            stakersData[_msgSender()].uniqueTokensStaked++;
            stakersData[_msgSender()].timestampAdded == 0
                ? stakersData[_msgSender()].timestampAdded = block.timestamp
                : stakersData[_msgSender()].timestampLastUpdated = block
                .timestamp;
            tokensStakersData[_token][_msgSender()].stakingRewardToken = _token;
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
        // require(tokensData[_token].isActive, "Token not active.");
        require(_amount > 0, "Amount must be greater than zero.");
        require(
            tokensStakersData[_token][_msgSender()].stakingBalance >= _amount,
            "Amount is greater than token staking balance."
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

        uint256 unstakeFee = (_amount / toWei(100)) *
            tokensData[_token].unstakeFee;
        uint256 unstakeAmount;
        if (unstakeFee == 0 || isExcludedFromFees[_msgSender()]) {
            unstakeAmount = _amount;
        } else {
            IERC20(_token).transfer(developmentWallet, unstakeFee);
            unstakeAmount = _amount - unstakeFee;
        }
        IERC20(_token).transfer(_msgSender(), unstakeAmount);
        emit Unstake(_msgSender(), _token, unstakeAmount);
    }

    function withdrawStakingReward(address _reward_token, uint256 _amount)
        public
    {
        require(_amount > 0, "Amount must be greater than zero.");
        require(
            tokensStakersData[_reward_token][_msgSender()].rewardBalance >=
                _amount,
            "Amount is greater than reward token balance."
        );
        tokensStakersData[_reward_token][_msgSender()].rewardBalance -= _amount;
        IERC20(_reward_token).transfer(_msgSender(), _amount);
        emit WithdrawStakingReward(_msgSender(), _reward_token, _amount);
    }

    function setStakingRewardToken(address _token, address _reward_token)
        public
    {
        setStakerRewardToken(_msgSender(), _token, _reward_token, true);
    }

    function setStakerRewardToken(
        address _staker,
        address _token,
        address _reward_token,
        bool validate
    ) internal returns (address) {
        if (validate) {
            require(
                stakersData[_msgSender()].isActive,
                "Staker does not have this token staked."
            );
            require(tokensData[_token].isActive, "Token not active.");
            require(
                tokensData[_reward_token].isActive,
                "Reward token not active."
            );
        }
        tokensStakersData[_token][_staker].stakingRewardToken = _reward_token;
        return tokensStakersData[_token][_staker].stakingRewardToken;
    }

    function calculateStakingRewardValue(address _token, address _staker)
        internal
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        if (!tokenExists(_token)) return (0, 0, 0, 0);
        TokenDetails memory tokenData = tokensData[_token];
        if (!stakerExists(_staker)) return (0, 0, 0, 0);
        TokenStakerDetails memory tokenStakerData = tokensStakersData[_token][
            _staker
        ];
        if (tokenStakerData.stakingBalance <= 0) return (0, 0, 0, 0);

        uint256 stakingValue = fromWei(
            tokenStakerData.stakingBalance * tokenData.price
        );
        uint256 rate = tokenData.stakingApr / 100;
        uint256 stakingTimestampStarted = tokenStakerData
            .timestampLastUpdated != 0
            ? tokenStakerData.timestampLastUpdated
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
            tokenStakerData.stakingRewardToken = setStakerRewardToken(
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
        ) = calculateStakingRewardValue(_token, _staker);
        if (stakingRewardValue == 0) return;

        uint256 stakerRewardTokenValue = getTokenValue(
            tokenStakerData.stakingRewardToken
        );
        if (stakerRewardTokenValue < stakingRewardValue) {
            if (tokenStakerData.stakingRewardToken == tokenData.rewardToken) {
                deactivateToken(_token);
                return;
            }
            tokenStakerData.stakingRewardToken = setStakerRewardToken(
                _staker,
                _token,
                tokenData.rewardToken,
                false
            );
            stakerRewardTokenValue = getTokenValue(
                tokenStakerData.stakingRewardToken
            );
            if (stakerRewardTokenValue < stakingRewardValue) {
                deactivateToken(_token);
                return;
            }
        }

        uint256 stakingRewardTokenPrice = tokensData[
            tokenStakerData.stakingRewardToken
        ].price;
        uint256 stakingRewardTokenAmount = toWei(
            stakingRewardValue / stakingRewardTokenPrice
        );
        if (stakingRewardTokenAmount <= 0) return;

        tokensData[tokenStakerData.stakingRewardToken]
            .rewardBalance -= stakingRewardTokenAmount;
        tokensData[tokenStakerData.stakingRewardToken]
            .timestampLastUpdated = block.timestamp;
        tokensStakersData[tokenStakerData.stakingRewardToken][_staker]
            .rewardBalance += stakingRewardTokenAmount;
        tokensStakersData[tokenStakerData.stakingRewardToken][_staker]
            .timestampLastUpdated = block.timestamp;
        tokensStakersData[_token][_staker].timestampLastUpdated = block
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
