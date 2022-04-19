// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract SavvyFinanceStaking is Ownable {
    IERC20 public rewardToken;
    address[] public allowedTokens;
    mapping(address => bool) public isAllowedToken;
    mapping(address => address) public allowedTokensPriceFeeds;
    mapping(address => address) public allowedTokensAdmins;
    mapping(address => uint256) public allowedTokensRewardBalances;
    address[] public rewardTokens;
    mapping(address => bool) public isRewardToken;
    address[] public stakers;
    mapping(address => bool) public isStaker;
    mapping(address => uint256) public stakersUniqueTokensStaked;
    mapping(address => uint256) public stakersRewards;
    mapping(address => mapping(address => uint256))
        public allowedTokensStakersBalances;

    constructor(address _reward_token) {
        rewardToken = IERC20(_reward_token);
    }

    function addAllowedToken(address _token) public onlyOwner {
        require(isAllowedToken[_token] == false, "Token already allowed.");
        allowedTokens.push(_token);
        isAllowedToken[_token] = true;
    }

    function removeAllowedToken(address _token) public onlyOwner {
        require(isAllowedToken[_token] == true, "Token not allowed.");
        removeFrom(allowedTokens, _token);
        delete isAllowedToken[_token];
    }

    function setAllowedTokenPriceFeed(address _token, address _price_feed)
        public
        onlyOwner
    {
        require(isAllowedToken[_token] == true, "Token not allowed.");
        allowedTokensPriceFeeds[_token] = _price_feed;
    }

    function setAllowedTokenAdmin(address _token, address _admin)
        public
        onlyOwner
    {
        require(isAllowedToken[_token] == true, "Token not allowed.");
        allowedTokensAdmins[_token] = _admin;
    }

    function updateAllowedTokenRewardBalance(
        address _token,
        uint256 _amount,
        string memory _action
    ) public {
        require(isAllowedToken[_token] == true, "Token not allowed.");
        require(
            allowedTokensAdmins[_token] == msg.sender,
            "Restricted to token admin."
        );
        require(_amount > 0, "Amount must be greater than zero.");
        if (
            keccak256(abi.encodePacked(_action)) ==
            keccak256(abi.encodePacked("add"))
        ) {
            require(
                IERC20(_token).balanceOf(msg.sender) >= _amount,
                "Insufficient balance."
            );
            IERC20(_token).transferFrom(msg.sender, address(this), _amount);
            allowedTokensRewardBalances += _amount;
        }
        if (
            keccak256(abi.encodePacked(_action)) ==
            keccak256(abi.encodePacked("remove"))
        ) {
            require(
                allowedTokensRewardBalances[_token] >= _amount,
                "Amount is greater than reward balance."
            );
            IERC20(_token).transfer(msg.sender, _amount);
            allowedTokensRewardBalances -= _amount;
        }
    }

    function addRewardToken(address _token) public onlyOwner {
        require(isRewardToken[_token] == false, "Already a reward token.");
        rewardTokens.push(_token);
        isRewardToken[_token] = true;
    }

    function removeRewardToken(address _token) public onlyOwner {
        require(isRewardToken[_token] == true, "Not a reward token.");
        removeFrom(rewardTokens, _token);
        delete isRewardToken[_token];
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

    function stakeToken(
        address _token,
        uint256 _amount,
        address _staker
    ) public {
        if (_staker == address(0x0)) _staker = msg.sender;
        require(isAllowedToken[_token] == true, "Token not allowed.");
        require(_amount > 0, "Amount must be greater than zero.");
        require(
            IERC20(_token).balanceOf(_staker) >= _amount,
            "Insufficient balance."
        );
        IERC20(_token).transferFrom(_staker, address(this), _amount);
        updateAllowedTokensStakersBalances(_staker, _token, "stake");
        allowedTokensStakersBalances[_token][_staker] += _amount;
    }

    function unstakeToken(
        address _token,
        uint256 _amount,
        address _staker
    ) public {
        if (_staker == address(0x0)) _staker = msg.sender;
        require(_amount > 0, "Amount must be greater than zero.");
        require(
            allowedTokensStakersBalances[_token][_staker] >= _amount,
            "Amount is greater than staking balance."
        );
        IERC20(_token).transfer(_staker, _amount);
        allowedTokensStakersBalances[_token][_staker] -= _amount;
        updateAllowedTokensStakersBalances(_staker, _token, "unstake");
    }

    function updateAllowedTokensStakersBalances(
        address _staker,
        address _token,
        string memory _action
    ) internal {
        if (allowedTokensStakersBalances[_token][_staker] <= 0) {
            if (
                keccak256(abi.encodePacked(_action)) ==
                keccak256(abi.encodePacked("stake"))
            ) {
                stakersUniqueTokensStaked[_staker]++;

                if (stakersUniqueTokensStaked[_staker] == 1) {
                    stakers.push(_staker);
                    isStaker[_staker] = true;
                }
            }
            if (
                keccak256(abi.encodePacked(_action)) ==
                keccak256(abi.encodePacked("unstake"))
            ) {
                stakersUniqueTokensStaked[_staker]--;

                if (stakersUniqueTokensStaked[_staker] == 0) {
                    removeFrom(stakers, _staker);
                    delete isStaker[_staker];
                }
            }
        }
    }

    function rewardStakers() public onlyOwner {
        for (
            uint256 stakersIndex = 0;
            stakersIndex < stakers.length;
            stakersIndex++
        ) {
            address staker = stakers[stakersIndex];
            if (stakersUniqueTokensStaked[staker] <= 0) continue;
            uint256 rewardAmount = getStakerTotalValue(staker, allowedTokens);
            stakersRewards[staker] += rewardAmount;
        }
    }

    function withdrawRewards(uint256 _amount) public {
        require(_amount > 0, "Amount must be greater than zero.");
        require(
            stakersRewards[msg.sender] >= _amount,
            "Amount is greater than staking rewards balance."
        );
        rewardToken.transfer(msg.sender, _amount);
        stakersRewards[msg.sender] -= _amount;
    }

    function getStakerTotalValue(address _staker, address[] memory _tokens)
        public
        view
        returns (uint256)
    {
        if (stakersUniqueTokensStaked[_staker] <= 0) return 0;
        uint256 stakerTotalValue = 0;
        for (
            uint256 tokensIndex = 0;
            tokensIndex < _tokens.length;
            tokensIndex++
        ) {
            stakerTotalValue += getStakerTokenValue(
                _staker,
                _tokens[tokensIndex]
            );
        }
        return stakerTotalValue;
    }

    function getStakerTokenValue(address _staker, address _token)
        public
        view
        returns (uint256)
    {
        if (stakersUniqueTokensStaked[_staker] <= 0) return 0;
        if (allowedTokensStakersBalances[_token][_staker] <= 0) return 0;
        (uint256 price, uint256 decimals) = getTokenPrice(_token);
        return ((allowedTokensStakersBalances[_token][_staker] * price) /
            (10**decimals));
    }

    function getTokenPrice(address _token)
        public
        view
        returns (uint256, uint256)
    {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(
            allowedTokensPriceFeeds[_token]
        );
        (, int256 price, , , ) = priceFeed.latestRoundData();
        return (uint256(price), uint256(priceFeed.decimals()));
    }

    function transferToken(
        address _token,
        address _to,
        uint256 _amount
    ) public onlyOwner {
        IERC20(_token).transfer(_to, _amount);
    }
}
