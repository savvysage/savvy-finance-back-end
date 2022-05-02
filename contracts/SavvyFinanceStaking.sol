// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract SavvyFinanceStaking is Ownable {
    address[] public tokens;
    mapping(address => bool) public tokenIsActive;
    struct Token {
        address admin;
        uint256 price;
        uint256 balance;
        uint256 timestampAdded;
        uint256 timestampLastUpdated;
    }
    mapping(address => Token) public tokensData;
    address[] public stakers;
    mapping(address => bool) public stakerIsActive;
    mapping(address => uint256) public stakersUniqueTokensStaked;
    struct Staker {
        uint256 balance;
        address rewardToken;
        uint256 rewardBalance;
        uint256 timestampAdded;
        uint256 timestampLastUpdated;
    }
    mapping(address => mapping(address => Staker)) public tokensStakersData;
    struct StakerRewardSwap {
        bool isSwapped;
        address token;
        uint256 amount;
    }
    struct StakerReward {
        uint256 amount;
        StakerRewardSwap swapData;
    }
    struct TokenReward {
        uint256 amount;
        mapping(address => StakerReward) stakersRewardsData;
        uint256 timestampAdded;
        uint256 timestampLastUpdated;
    }
    mapping(address => TokenReward[]) public tokensRewardsData;
    uint256 public interestRate;

    function tokenExists(address _token) public returns (bool) {
        for (uint256 tokenIndex = 0; tokenIndex < tokens.length; tokenIndex++) {
            if (tokens[tokenIndex] == _token) return true;
        }
        return false;
    }

    function addToken(address _token, address _admin) public onlyOwner {
        require(!tokenExists(_token), "Token already exists.");
        tokens.push(_token);
        tokensData[_token].admin = _admin == address(0x0) ? msg.sender : _admin;
        tokensData[_token].timestampAdded = block.timestamp;
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
        tokensData[_token].admin = _admin;
        tokensData[_token].timestampLastUpdated = block.timestamp;
    }

    function setTokenPrice(address _token, uint256 _price) public onlyOwner {
        require(tokenExists(_token), "Token does not exist.");
        tokensData[_token].price = _price;
        tokensData[_token].timestampLastUpdated = block.timestamp;
    }

    function depositToken(address _token, uint256 _amount) public {
        require(tokenExists(_token), "Token does not exist.");
        require(
            msg.sender == tokensData[_token].admin,
            "Only the token admin can do this."
        );
        require(_amount > 0, "Amount must be greater than zero.");
        require(
            IERC20(_token).balanceOf(msg.sender) >= _amount,
            "Insufficient token balance."
        );
        IERC20(_token).transferFrom(msg.sender, address(this), _amount);
        tokensData[_token].balance += _amount;
    }

    function withdrawToken(address _token, uint256 _amount) public {
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
        if (tokensStakersData[_token][msg.sender].balance == 0) {
            if (stakersUniqueTokensStaked[msg.sender] == 0) {
                stakers.push(msg.sender);
                stakerIsActive[msg.sender] = true;
            }
            stakersUniqueTokensStaked[msg.sender]++;
            tokensStakersData[_token][msg.sender].rewardToken = _token;
        }
        tokensStakersData[_token][msg.sender].balance += _amount;
    }

    function unstakeToken(address _token, uint256 _amount) public {
        // require(tokenIsActive[_token], "Token not active.");
        require(_amount > 0, "Amount must be greater than zero.");
        require(
            tokensStakersData[_token][msg.sender].balance >= _amount,
            "Amount is greater than token staking balance."
        );
        IERC20(_token).transfer(msg.sender, _amount);
        if (tokensStakersData[_token][msg.sender].balance == _amount) {
            if (stakersUniqueTokensStaked[msg.sender] == 1) {
                stakerIsActive[msg.sender] = false;
            }
            stakersUniqueTokensStaked[msg.sender]--;
        }
        tokensStakersData[_token][msg.sender].balance -= _amount;
    }

    function updateStakersRewardToken(address _token, address _reward_token)
        public
    {
        require(stakerIsActive[msg.sender], "You have no staked token.");
        require(tokenIsActive[_token], "Token not active.");
        require(tokenIsActive[_reward_token], "Reward token not active.");
        if (tokensStakersData[_token][msg.sender].rewardBalance > 0) {
            IERC20(tokensStakersData[_token][msg.sender].rewardToken).transfer(
                msg.sender,
                tokensStakersData[_token][msg.sender].rewardBalance
            );

            tokensStakersData[_token][msg.sender].rewardBalance = 0;
        }
        tokensStakersData[_token][msg.sender].rewardToken = _reward_token;
    }

    function rewardStakers() public onlyOwner {
        for (uint256 tokenIndex = 0; tokenIndex < tokens.length; tokenIndex++) {
            address token = tokens[tokenIndex];
            if (!tokenIsActive[token]) continue;
            uint256 tokenPrice = tokensData[token].price;
            uint256 tokenRewardIndex = tokensRewardsData[token].length;
            uint256 tokenRewardAmount;
            for (
                uint256 stakerIndex = 0;
                stakerIndex < stakers.length;
                stakerIndex++
            ) {
                address staker = stakers[stakerIndex];
                if (!stakerIsActive[staker]) continue;
                uint256 stakerTokenBalance = tokensStakersData[token][staker]
                    .balance;
                if (stakerTokenBalance <= 0) continue;
                uint256 stakerRewardAmount = (stakerTokenBalance * tokenPrice) /
                    (100 / interestRate);
                tokenRewardAmount += stakerRewardAmount;
                tokensRewardsData[token][tokenRewardIndex]
                    .stakersRewardsData[staker]
                    .amount = stakerRewardAmount;
                tokensStakersData[token][staker]
                    .rewardBalance += stakerRewardAmount;
            }
            tokensData[token].balance -= tokenRewardAmount;
            tokensRewardsData[token][tokenRewardIndex]
                .amount = tokenRewardAmount;
            tokensRewardsData[token][tokenRewardIndex].timestampAdded = block
                .timestamp;
        }
    }

    function withdrawReward(address _token, uint256 _amount) public {
        require(_amount > 0, "Amount must be greater than zero.");
        require(
            tokensStakersData[_token][msg.sender].rewardBalance >= _amount,
            "Amount is greater than token reward balance."
        );
        IERC20(_token).transfer(msg.sender, _amount);
        tokensStakersData[_token][msg.sender].rewardBalance -= _amount;
    }

    function removeFrom(address[] storage _array, address _arrayValue)
        internal
    {
        for (uint256 arrayIndex = 0; arrayIndex < _array.length; arrayIndex++) {
            if (_array[arrayIndex] == _arrayValue) {
                // move to last index
                _array[arrayIndex] = _array[_array.length - 1];
                // delete last index
                _array.pop();
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
