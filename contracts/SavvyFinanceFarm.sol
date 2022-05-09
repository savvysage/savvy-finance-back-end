// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract SavvyFinanceFarm is Ownable, AccessControl {
    bytes32 public constant TOKEN_ADMIN_ROLE = keccak256("TOKEN_ADMIN_ROLE");

    address[] public tokens;
    mapping(address => bool) public tokenIsActive;
    enum TokenType {
        DEFAULT,
        LP
    }
    struct TokenDetails {
        TokenType tokenType;
        address admin;
        address rewardToken;
        uint256 rewardBalance;
        uint256 interestRate;
        uint256 price;
        uint256 timestampAdded;
        uint256 timestampLastUpdated;
    }
    mapping(address => TokenDetails) public tokensData;

    struct TokenRewardDetails {
        uint256 amount;
        mapping(address => uint256) stakersAmount;
        uint256 timestampAdded;
        uint256 timestampLastUpdated;
    }
    mapping(address => TokenRewardDetails[]) public tokensRewardsData;

    address[] public stakers;
    mapping(address => bool) public stakerIsActive;
    struct StakerDetails {
        uint256 uniqueTokensStaked;
        uint256 timestampAdded;
        uint256 timestampLastUpdated;
    }
    mapping(address => StakerDetails) public stakersData;

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

    uint256 minimumInterestRate = 0.1 * (10**18);
    uint256 maximumInterestRate = 5 * (10**18);

    constructor() {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function getTokens() public view returns (address[] memory) {
        return tokens;
    }

    function getStakers() public view returns (address[] memory) {
        return stakers;
    }

    function tokenExists(address _token) public view returns (bool) {
        for (uint256 tokenIndex = 0; tokenIndex < tokens.length; tokenIndex++) {
            if (tokens[tokenIndex] == _token) return true;
        }
        return false;
    }

    function addToken(
        address _token,
        address _admin,
        address _reward_token,
        TokenType _type
    ) public onlyOwner {
        require(!tokenExists(_token), "Token already exists.");
        tokens.push(_token);
        tokensData[_token].admin = _admin == address(0x0) ? msg.sender : _admin;
        tokensData[_token].rewardToken = _reward_token == address(0x0)
            ? _token
            : _reward_token;
        tokensData[_token].tokenType == _type;
        tokensData[_token].timestampAdded = block.timestamp;

        grantRole(TOKEN_ADMIN_ROLE, tokensData[_token].admin);
    }

    function activateToken(address _token) public onlyOwner {
        require(tokenExists(_token), "Token does not exist.");
        tokenIsActive[_token] = true;
    }

    function deactivateToken(address _token) public onlyOwner {
        require(tokenExists(_token), "Token does not exist.");
        tokenIsActive[_token] = false;
    }

    function setTokenAdmin(address _token, address _admin) public onlyOwner {
        require(tokenExists(_token), "Token does not exist.");
        revokeRole(TOKEN_ADMIN_ROLE, tokensData[_token].admin);
        tokensData[_token].admin = _admin;
        tokensData[_token].timestampLastUpdated = block.timestamp;
        grantRole(TOKEN_ADMIN_ROLE, tokensData[_token].admin);
    }

    function setTokenRewardToken(address _token, address _reward_token)
        public
        onlyOwner
    {
        require(tokenExists(_token), "Token does not exist.");
        require(tokenExists(_reward_token), "Reward token does not exist.");
        tokensData[_token].rewardToken = _reward_token;
        tokensData[_token].timestampLastUpdated = block.timestamp;
    }

    function setTokenPrice(address _token, uint256 _price) public onlyOwner {
        require(tokenExists(_token), "Token does not exist.");
        tokensData[_token].price = _price;
        tokensData[_token].timestampLastUpdated = block.timestamp;
    }

    function setTokenInterestRate(address _token, uint256 _interestRate)
        public
        onlyRole(TOKEN_ADMIN_ROLE)
    {
        require(tokenExists(_token), "Token does not exist.");
        require(
            _interestRate >= minimumInterestRate &&
                _interestRate <= maximumInterestRate,
            string(
                abi.encodePacked(
                    "Interest rate must be between",
                    minimumInterestRate,
                    "and",
                    maximumInterestRate,
                    "."
                )
            )
        );
        tokensData[_token].interestRate = _interestRate;
        tokensData[_token].timestampLastUpdated = block.timestamp;
    }

    function depositToken(address _token, uint256 _amount)
        public
        onlyRole(TOKEN_ADMIN_ROLE)
    {
        require(tokenExists(_token), "Token does not exist.");
        require(_amount > 0, "Amount must be greater than zero.");
        require(
            IERC20(_token).balanceOf(msg.sender) >= _amount,
            "Insufficient token balance."
        );
        IERC20(_token).transferFrom(msg.sender, address(this), _amount);
        tokensData[_token].rewardBalance += _amount;
    }

    function withdrawToken(address _token, uint256 _amount)
        public
        onlyRole(TOKEN_ADMIN_ROLE)
    {
        require(tokenExists(_token), "Token does not exist.");
        require(
            msg.sender == tokensData[_token].admin,
            "Only the token admin can do this."
        );
        require(_amount > 0, "Amount must be greater than zero.");
        require(
            tokensData[_token].rewardBalance >= _amount,
            "Amount is greater than token balance."
        );
        IERC20(_token).transfer(msg.sender, _amount);
        tokensData[_token].rewardBalance -= _amount;
    }

    function stakeToken(address _token, uint256 _amount) public {
        require(tokenIsActive[_token], "Token not active.");
        require(_amount > 0, "Amount must be greater than zero.");
        require(
            IERC20(_token).balanceOf(msg.sender) >= _amount,
            "Insufficient token balance."
        );
        IERC20(_token).transferFrom(msg.sender, address(this), _amount);
        if (stakingData[_token][msg.sender].balance == 0) {
            if (stakersData[msg.sender].uniqueTokensStaked == 0) {
                stakers.push(msg.sender);
                stakerIsActive[msg.sender] = true;
            }
            stakersData[msg.sender].uniqueTokensStaked++;
            stakersData[msg.sender].timestampLastUpdated = block.timestamp;
            stakingData[_token][msg.sender].rewardToken = _token;
        }
        stakingData[_token][msg.sender].balance += _amount;
    }

    function unstakeToken(address _token, uint256 _amount) public {
        // require(tokenIsActive[_token], "Token not active.");
        require(_amount > 0, "Amount must be greater than zero.");
        require(
            stakingData[_token][msg.sender].balance >= _amount,
            "Amount is greater than token staking balance."
        );
        if (stakingData[_token][msg.sender].balance == _amount) {
            if (stakersData[msg.sender].uniqueTokensStaked == 1) {
                stakerIsActive[msg.sender] = false;
            }
            stakersData[msg.sender].uniqueTokensStaked--;
            stakersData[msg.sender].timestampLastUpdated = block.timestamp;
        }
        stakingData[_token][msg.sender].balance -= _amount;
        IERC20(_token).transfer(msg.sender, _amount);
    }

    function setStakingRewardToken(address _token, address _reward_token)
        public
    {
        require(
            stakerIsActive[msg.sender],
            "You do not have this token staked."
        );
        require(tokenIsActive[_token], "Token not active.");
        require(tokenIsActive[_reward_token], "Reward token not active.");
        stakingData[_token][msg.sender].rewardToken = _reward_token;
    }

    function rewardStakers() public onlyOwner {
        for (uint256 tokenIndex = 0; tokenIndex < tokens.length; tokenIndex++) {
            address token = tokens[tokenIndex];
            if (!tokenIsActive[token]) continue;
            uint256 tokenPrice = tokensData[token].price;
            uint256 tokenInterestRate = tokensData[token].interestRate;
            uint256 tokenRewardIndex = tokensRewardsData[token].length;
            uint256 tokenRewardAmount;
            for (
                uint256 stakerIndex = 0;
                stakerIndex < stakers.length;
                stakerIndex++
            ) {
                address staker = stakers[stakerIndex];
                if (!stakerIsActive[staker]) continue;
                uint256 stakerTokenBalance = stakingData[token][staker].balance;
                if (stakerTokenBalance <= 0) continue;
                uint256 stakerRewardAmount = (stakerTokenBalance * tokenPrice) /
                    (100 / tokenInterestRate);
                tokenRewardAmount += stakerRewardAmount;
                tokensRewardsData[token][tokenRewardIndex].stakersAmount[
                        staker
                    ] = stakerRewardAmount;
                stakingRewardsData[token][staker].balance += stakerRewardAmount;
            }
            tokensData[token].rewardBalance -= tokenRewardAmount;
            tokensRewardsData[token][tokenRewardIndex]
                .amount = tokenRewardAmount;
            tokensRewardsData[token][tokenRewardIndex].timestampAdded = block
                .timestamp;
        }
    }

    function withdrawReward(address _token, uint256 _amount) public {
        require(_amount > 0, "Amount must be greater than zero.");
        require(
            stakingRewardsData[_token][msg.sender].balance >= _amount,
            "Amount is greater than token reward balance."
        );
        stakingRewardsData[_token][msg.sender].balance -= _amount;
        IERC20(_token).transfer(msg.sender, _amount);
    }

    function transferToken(
        address _token,
        address _to,
        uint256 _amount
    ) public onlyOwner {
        IERC20(_token).transfer(_to, _amount);
    }
}
