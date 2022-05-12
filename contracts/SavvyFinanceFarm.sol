// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract SavvyFinanceFarm is Ownable, AccessControl {
    bytes32 public constant TOKEN_ADMIN_ROLE = keccak256("TOKEN_ADMIN_ROLE");
    uint256 minimumStakingApr;
    uint256 maximumStakingApr;

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
        uint256 stakingApr;
        address rewardToken;
        address admin;
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

    constructor() {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        minimumStakingApr = 50 * (10**18);
        maximumStakingApr = 1000 * (10**18);
    }

    function setAprDetails(
        uint256 _minimumStakingApr,
        uint256 _maximumStakingApr
    ) public onlyOwner {
        minimumStakingApr = _minimumStakingApr;
        maximumStakingApr = _maximumStakingApr;
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
        TokenType _tokenType,
        uint256 _stakingApr,
        address _reward_token,
        address _admin
    ) public onlyOwner {
        require(!tokenExists(_token), "Token already exists.");
        tokens.push(_token);
        tokensData[_token].tokenType == _tokenType;
        tokensData[_token].timestampAdded = block.timestamp;
        setTokenStakingApr(
            _token,
            _stakingApr == 0 ? 365 * (10**18) : _stakingApr
        );
        setTokenRewardToken(
            _token,
            _reward_token == address(0x0) ? _token : _reward_token
        );
        setTokenAdmin(_token, _admin == address(0x0) ? msg.sender : _admin);
        // tokensData[_token].stakingApr == _stakingApr == 0
        //     ? 365 * (10**18)
        //     : _stakingApr;
        // tokensData[_token].rewardToken = _reward_token == address(0x0)
        //     ? _token
        //     : _reward_token;
        // tokensData[_token].admin = _admin == address(0x0) ? msg.sender : _admin;
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

    function setTokenPrice(address _token, uint256 _price) public onlyOwner {
        require(tokenExists(_token), "Token does not exist.");
        tokensData[_token].price = _price;
        tokensData[_token].timestampLastUpdated = block.timestamp;
    }

    function setTokenAdmin(address _token, address _admin) public onlyOwner {
        require(tokenExists(_token), "Token does not exist.");
        revokeRole(TOKEN_ADMIN_ROLE, tokensData[_token].admin);
        tokensData[_token].admin = _admin;
        tokensData[_token].timestampLastUpdated = block.timestamp;
        grantRole(TOKEN_ADMIN_ROLE, tokensData[_token].admin);
    }

    function setTokenStakingApr(address _token, uint256 _stakingApr)
        public
        onlyRole(TOKEN_ADMIN_ROLE)
    {
        require(tokenExists(_token), "Token does not exist.");
        require(
            _stakingApr >= minimumStakingApr &&
                _stakingApr <= maximumStakingApr,
            string(
                abi.encodePacked(
                    "Stakng APR must be between",
                    minimumStakingApr,
                    "and",
                    maximumStakingApr,
                    "."
                )
            )
        );
        tokensData[_token].stakingApr = _stakingApr;
        tokensData[_token].timestampLastUpdated = block.timestamp;
    }

    function setTokenRewardToken(address _token, address _reward_token)
        public
        onlyRole(TOKEN_ADMIN_ROLE)
    {
        require(tokenExists(_token), "Token does not exist.");
        require(tokenExists(_reward_token), "Reward token does not exist.");
        require(
            tokensData[_token].admin == tokensData[_reward_token].admin,
            "Token admin should be same as reward token admin."
        );
        tokensData[_token].rewardToken = _reward_token;
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
        tokensData[_token].balance += _amount;
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
            tokensData[_token].balance >= _amount,
            "Amount is greater than token balance."
        );
        IERC20(_token).transfer(msg.sender, _amount);
        tokensData[_token].balance -= _amount;
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
        setStakerRewardToken(msg.sender, _token, _reward_token, true);
    }

    function setStakerRewardToken(
        address _staker,
        address _token,
        address _reward_token,
        bool validate
    ) internal onlyOwner returns (address) {
        if (validate) {
            require(
                stakerIsActive[msg.sender],
                "You do not have this token staked."
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
            stakingRewardsData[_token][msg.sender].balance >= _amount,
            "Amount is greater than token reward balance."
        );
        stakingRewardsData[_token][msg.sender].balance -= _amount;
        IERC20(_token).transfer(msg.sender, _amount);
    }

    function rewardStakers() public onlyOwner {
        for (uint256 tokenIndex = 0; tokenIndex < tokens.length; tokenIndex++) {
            address token = tokens[tokenIndex];
            if (!tokenIsActive[token]) continue;

            uint256 tokenPrice = tokensData[token].price;
            uint256 tokenStakingApr = tokensData[token].stakingApr;
            uint256 tokenInterestRateDaily = tokenStakingApr / (365 * (10**18));
            address tokenRewardToken = tokensData[token].rewardToken;
            uint256 tokenRewardIndex = tokensRewardsData[token].length;
            uint256 tokenRewardTokenAmount;

            for (
                uint256 stakerIndex = 0;
                stakerIndex < stakers.length;
                stakerIndex++
            ) {
                address staker = stakers[stakerIndex];
                if (!stakerIsActive[staker]) continue;

                uint256 stakerBalance = stakingData[token][staker].balance;
                if (stakerBalance <= 0) continue;
                uint256 stakerRewardValue = (stakerBalance * tokenPrice) /
                    (100 / tokenInterestRateDaily);

                address stakerRewardToken = stakingData[token][staker]
                    .rewardToken;
                if (!tokenIsActive[stakerRewardToken]) continue;
                // if (!tokenIsActive[stakerRewardToken]) {
                //     if (stakerRewardToken == tokenRewardToken) continue;
                //     stakerRewardToken = setStakerRewardToken(
                //         staker,
                //         token,
                //         tokenRewardToken,
                //         false
                //     );
                //     if (!tokenIsActive[stakerRewardToken]) continue;
                // }

                uint256 stakerRewardTokenBalance = tokensData[stakerRewardToken]
                    .balance;
                uint256 stakerRewardTokenPrice = tokensData[stakerRewardToken]
                    .price;
                uint256 stakerRewardTokenValue = stakerRewardTokenBalance *
                    stakerRewardTokenPrice;

                if (stakerRewardTokenValue < stakerRewardValue) {
                    deactivateToken(stakerRewardToken);
                    continue;
                    // if (stakerRewardToken == tokenRewardToken) {
                    //     deactivateToken(stakerRewardToken);
                    //     continue;
                    // }
                    // stakerRewardToken = setStakerRewardToken(
                    //     staker,
                    //     token,
                    //     tokenRewardToken,
                    //     false
                    // );
                    // if (stakerRewardTokenValue < stakerRewardValue) {
                    //     deactivateToken(stakerRewardToken);
                    //     continue;
                    // }
                }

                uint256 stakerRewardTokenAmount = stakerRewardValue /
                    stakerRewardTokenPrice;
                tokenRewardTokenAmount += stakerRewardTokenAmount;

                // tokensRewardsData[token][tokenRewardIndex].stakersAmount[
                //         staker
                //     ] = stakerRewardTokenAmount;
                // stakingRewardsData[token][staker]
                //     .balance += stakerRewardTokenAmount;
            }

            tokensData[tokenRewardToken].balance -= tokenRewardTokenAmount;
            // tokensRewardsData[token][tokenRewardIndex]
            //     .amount = tokenRewardTokenAmount;
            // tokensRewardsData[token][tokenRewardIndex].timestampAdded = block
            //     .timestamp;
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
