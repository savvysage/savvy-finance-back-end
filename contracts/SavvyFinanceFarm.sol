// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract SavvyFinanceFarm is Ownable, AccessControl {
    string[] public testData;

    address constant ZERO_ADDRESS = 0x0000000000000000000000000000000000000000;
    address developmentWallet;
    uint256 public minimumStakingApr;
    uint256 public maximumStakingApr;
    uint256 public minimumStakingFee;
    uint256 public maximumStakingFee;

    address[] public tokens;
    mapping(address => bool) public tokenIsActive;
    enum TokenType {
        DEFAULT,
        LP
    }
    struct TokenDetails {
        TokenType tokenType;
        uint256 balance;
        uint256 price;
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
    mapping(address => bool) public stakerIsActive;
    struct StakerDetails {
        uint256 uniqueTokensStaked;
        uint256 timestampAdded;
        uint256 timestampLastUpdated;
    }
    mapping(address => StakerDetails) public stakersData;

    struct StakerRewardDetails {
        uint256 id;
        address token;
        address rewardToken;
        uint256 rewardAmount;
        uint256 timestampAdded;
        uint256 timestampLastUpdated;
    }
    mapping(address => StakerRewardDetails[]) public stakersRewardsData;

    struct StakingDetails {
        uint256 balance;
        address rewardToken;
        uint256 timestampAdded;
        uint256 timestampLastUpdated;
    }
    mapping(address => mapping(address => StakingDetails)) public stakingData;

    struct StakingRewardDetails {
        uint256 balance;
        uint256 timestampAdded;
        uint256 timestampLastUpdated;
    }
    mapping(address => mapping(address => StakingRewardDetails))
        public stakingRewardsData;

    event Stake(address indexed staker, address indexed token, uint256 amount);
    event Unstake(
        address indexed staker,
        address indexed token,
        uint256 amount
    );
    event WithdrawStakingReward(
        address indexed staker,
        address indexed token,
        uint256 amount
    );

    constructor() {
        developmentWallet = _msgSender();
        minimumStakingApr = 50 * (10**18);
        maximumStakingApr = 1000 * (10**18);
        minimumStakingFee = 0;
        maximumStakingFee = 100 * (10**18);
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
    }

    function getTestData() public view returns (string[] memory) {
        return testData;
    }

    function toRole(address a) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(a));
    }

    function getTokens() public view returns (address[] memory) {
        return tokens;
    }

    function getStakers() public view returns (address[] memory) {
        return stakers;
    }

    function getStakerRewardsData(address _staker)
        public
        view
        returns (StakerRewardDetails[] memory)
    {
        return stakersRewardsData[_staker];
    }

    function setDevelopmentWallet(address _developmentWallet) public onlyOwner {
        developmentWallet = _developmentWallet;
    }

    function setAprDetails(
        uint256 _minimumStakingApr,
        uint256 _maximumStakingApr
    ) public onlyOwner {
        minimumStakingApr = _minimumStakingApr;
        maximumStakingApr = _maximumStakingApr;
    }

    function setFeeDetails(
        uint256 _minimumStakingFee,
        uint256 _maximumStakingFee
    ) public onlyOwner {
        minimumStakingFee = _minimumStakingFee;
        maximumStakingFee = _maximumStakingFee;
    }

    function tokenExists(address _token) public view returns (bool) {
        for (uint256 tokenIndex = 0; tokenIndex < tokens.length; tokenIndex++) {
            if (tokens[tokenIndex] == _token) return true;
        }
        return false;
    }

    function addToken(
        address _token,
        TokenType _tokenType,
        uint256 _stakeFee,
        uint256 _unstakeFee,
        uint256 _stakingApr,
        address _reward_token,
        address _admin
    ) public onlyOwner {
        require(!tokenExists(_token), "Token already exists.");
        _setupRole(toRole(_token), _msgSender());
        tokens.push(_token);
        tokensData[_token].tokenType == _tokenType;
        tokensData[_token].timestampAdded = block.timestamp;
        setTokenStakingFees(
            _token,
            _stakeFee == 0 ? 10**18 : _stakeFee,
            _unstakeFee == 0 ? 10**18 : _unstakeFee
        );
        setTokenStakingApr(
            _token,
            _stakingApr == 0 ? 365 * (10**18) : _stakingApr
        );
        setTokenRewardToken(
            _token,
            _reward_token == address(0x0) ? _token : _reward_token
        );
        setTokenAdmin(_token, _admin == address(0x0) ? _msgSender() : _admin);
    }

    function activateToken(address _token) public onlyOwner {
        require(tokenExists(_token), "Token does not exist.");
        tokenIsActive[_token] = true;
    }

    function deactivateToken(address _token) public onlyOwner {
        require(tokenExists(_token), "Token does not exist.");
        tokenIsActive[_token] = false;
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
                    minimumStakingFee / (10**18),
                    "and",
                    maximumStakingFee / (10**18),
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
                    minimumStakingFee / (10**18),
                    "and",
                    maximumStakingFee / (10**18),
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
                    minimumStakingApr / (10**18),
                    "and",
                    maximumStakingApr / (10**18),
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
        tokensData[_token].balance += _amount;
    }

    function withdrawToken(address _token, uint256 _amount)
        public
        onlyRole(toRole(_token))
    {
        require(tokenExists(_token), "Token does not exist.");
        require(_amount > 0, "Amount must be greater than zero.");
        require(
            tokensData[_token].balance >= _amount,
            "Amount is greater than token balance."
        );
        tokensData[_token].balance -= _amount;
        IERC20(_token).transfer(_msgSender(), _amount);
    }

    function stakeToken(address _token, uint256 _amount) public {
        require(tokenIsActive[_token], "Token not active.");
        require(_amount > 0, "Amount must be greater than zero.");
        require(
            IERC20(_token).balanceOf(_msgSender()) >= _amount,
            "Insufficient token balance."
        );

        uint256 stakeFee = (_amount / (100 * (10**18))) *
            tokensData[_token].stakeFee;
        if (stakeFee != 0)
            IERC20(_token).transferFrom(
                _msgSender(),
                developmentWallet,
                stakeFee
            );
        uint256 stakeAmount = _amount - stakeFee;
        IERC20(_token).transferFrom(_msgSender(), address(this), stakeAmount);

        if (stakingData[_token][_msgSender()].balance == 0) {
            if (stakersData[_msgSender()].uniqueTokensStaked == 0) {
                stakers.push(_msgSender());
                stakerIsActive[_msgSender()] = true;
            }
            stakersData[_msgSender()].uniqueTokensStaked++;
            stakersData[_msgSender()].timestampAdded == 0
                ? stakersData[_msgSender()].timestampAdded = block.timestamp
                : stakersData[_msgSender()].timestampLastUpdated = block
                .timestamp;
            stakingData[_token][_msgSender()].rewardToken = _token;
        }

        stakingData[_token][_msgSender()].balance += stakeAmount;
        stakingData[_token][_msgSender()].timestampAdded == 0
            ? stakingData[_token][_msgSender()].timestampAdded = block.timestamp
            : stakingData[_token][_msgSender()].timestampLastUpdated = block
            .timestamp;
        emit Stake(_msgSender(), _token, stakeAmount);
    }

    function unstakeToken(address _token, uint256 _amount) public {
        // require(tokenIsActive[_token], "Token not active.");
        require(_amount > 0, "Amount must be greater than zero.");
        require(
            stakingData[_token][_msgSender()].balance >= _amount,
            "Amount is greater than token staking balance."
        );

        if (stakingData[_token][_msgSender()].balance == _amount) {
            if (stakersData[_msgSender()].uniqueTokensStaked == 1) {
                stakerIsActive[_msgSender()] = false;
            }
            stakersData[_msgSender()].uniqueTokensStaked--;
            stakersData[_msgSender()].timestampAdded == 0
                ? stakersData[_msgSender()].timestampAdded = block.timestamp
                : stakersData[_msgSender()].timestampLastUpdated = block
                .timestamp;
        }

        stakingData[_token][_msgSender()].balance -= _amount;
        stakingData[_token][_msgSender()].timestampAdded == 0
            ? stakingData[_token][_msgSender()].timestampAdded = block.timestamp
            : stakingData[_token][_msgSender()].timestampLastUpdated = block
            .timestamp;

        uint256 unstakeFee = (_amount / (100 * (10**18))) *
            tokensData[_token].unstakeFee;
        if (unstakeFee != 0)
            IERC20(_token).transfer(developmentWallet, unstakeFee);
        uint256 unstakeAmount = _amount - unstakeFee;
        IERC20(_token).transfer(_msgSender(), unstakeAmount);
        emit Unstake(_msgSender(), _token, unstakeAmount);
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
    ) internal onlyOwner returns (address) {
        if (validate) {
            require(
                stakerIsActive[_msgSender()],
                "Staker does not have this token staked."
            );
            require(tokenIsActive[_token], "Token not active.");
            require(tokenIsActive[_reward_token], "Reward token not active.");
        }
        stakingData[_token][_staker].rewardToken = _reward_token;
        return stakingData[_token][_staker].rewardToken;
    }

    function withdrawStakingReward(address _token, uint256 _amount) public {
        require(_amount > 0, "Amount must be greater than zero.");
        require(
            stakingRewardsData[_token][_msgSender()].balance >= _amount,
            "Amount is greater than token reward balance."
        );
        stakingRewardsData[_token][_msgSender()].balance -= _amount;
        IERC20(_token).transfer(_msgSender(), _amount);
        emit WithdrawStakingReward(_msgSender(), _token, _amount);
    }

    function rewardStaker(address _staker, address _token)
        public
        onlyOwner
        returns (address, uint256)
    {
        if (!stakerIsActive[_staker]) return (ZERO_ADDRESS, 0);

        TokenDetails memory tokenData;
        tokenData.price = tokensData[_token].price;
        tokenData.rewardToken = tokensData[_token].rewardToken;
        tokenData.stakingApr = tokensData[_token].stakingApr;
        uint256 tokenInterestRateDaily = tokenData.stakingApr /
            (365 * (10**18));

        StakingDetails memory stakerData;
        stakerData.balance = stakingData[_token][_staker].balance;
        if (stakerData.balance <= 0) return (ZERO_ADDRESS, 0);
        uint256 stakerRewardValue = (stakerData.balance * tokenData.price) /
            (100 / tokenInterestRateDaily);

        stakerData.rewardToken = stakingData[_token][_staker].rewardToken;
        if (!tokenIsActive[stakerData.rewardToken]) {
            if (stakerData.rewardToken == tokenData.rewardToken)
                return (ZERO_ADDRESS, 0);
            stakerData.rewardToken = setStakerRewardToken(
                _staker,
                _token,
                tokenData.rewardToken,
                false
            );
            if (!tokenIsActive[stakerData.rewardToken])
                return (ZERO_ADDRESS, 0);
        }

        uint256 stakerRewardTokenBalance = tokensData[stakerData.rewardToken]
            .balance;
        uint256 stakerRewardTokenPrice = tokensData[stakerData.rewardToken]
            .price;
        uint256 stakerRewardTokenValue = stakerRewardTokenBalance *
            stakerRewardTokenPrice;

        if (stakerRewardTokenValue < stakerRewardValue) {
            if (stakerData.rewardToken == tokenData.rewardToken) {
                deactivateToken(stakerData.rewardToken);
                return (ZERO_ADDRESS, 0);
            }
            stakerData.rewardToken = setStakerRewardToken(
                _staker,
                _token,
                tokenData.rewardToken,
                false
            );
            if (stakerRewardTokenValue < stakerRewardValue) {
                deactivateToken(stakerData.rewardToken);
                return (ZERO_ADDRESS, 0);
            }
        }

        uint256 stakerRewardTokenAmount = stakerRewardValue /
            stakerRewardTokenPrice;

        tokensData[stakerData.rewardToken].balance -= stakerRewardTokenAmount;
        tokensData[stakerData.rewardToken].timestampLastUpdated = block
            .timestamp;
        stakingRewardsData[stakerData.rewardToken][_staker]
            .balance += stakerRewardTokenAmount;
        stakingRewardsData[stakerData.rewardToken][_staker]
            .timestampLastUpdated = block.timestamp;

        return (stakerData.rewardToken, stakerRewardTokenAmount);
    }

    function rewardStakers() public onlyOwner {
        for (uint256 tokenIndex = 0; tokenIndex < tokens.length; tokenIndex++) {
            address token = tokens[tokenIndex];
            if (!tokenIsActive[token]) continue;

            StakerRewardDetails memory stakerRewardData;

            for (
                uint256 stakerIndex = 0;
                stakerIndex < stakers.length;
                stakerIndex++
            ) {
                address staker = stakers[stakerIndex];

                (
                    address stakerRewardToken,
                    uint256 stakerRewardTokenAmount
                ) = rewardStaker(staker, token);
                if (
                    stakerRewardToken == address(0x0) ||
                    stakerRewardTokenAmount == 0
                ) continue;

                stakerRewardData.id = stakersRewardsData[staker].length;
                stakerRewardData.token = token;
                stakerRewardData.rewardToken = stakerRewardToken;
                stakerRewardData.rewardAmount = stakerRewardTokenAmount;
                stakerRewardData.timestampAdded = block.timestamp;
                stakersRewardsData[staker].push(stakerRewardData);
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
