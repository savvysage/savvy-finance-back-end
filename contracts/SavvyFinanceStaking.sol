// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract SavvyFinanceStaking is Ownable {
    address[] public allowedTokens;
    mapping(address => bool) public isAllowedToken;
    mapping(address => bool) public isStakableAllowedToken;
    struct allowedTokenDetails {
        address admin;
        address rewardToken;
        uint256 price;
        uint256 balance;
    }
    mapping(address => allowedTokenDetails) public allowedTokensData;
    address[] public stakers;
    mapping(address => bool) public isStaker;
    struct stakingDetails {
        uint256 balance;
        address rewardToken;
        uint256 rewardBalance;
    }
    mapping(address => mapping(address => stakingDetails)) public stakingData;
    mapping(address => uint256) public stakersUniqueTokensStaked;
    uint256 public interestRate;

    function addAllowedToken(address _token) public onlyOwner {
        require(isAllowedToken[_token] == false, "Token already allowed.");
        allowedTokens.push(_token);
        isAllowedToken[_token] = true;
        allowedTokensData[_token].admin = msg.sender;
        allowedTokensData[_token].rewardToken = _token;
        isStakableAllowedToken[_token] = true;
    }

    function removeAllowedToken(address _token) public onlyOwner {
        require(isAllowedToken[_token] == true, "Token not allowed.");
        delete isAllowedToken[_token];
        removeFrom(allowedTokens, _token);
    }

    function setAllowedTokenAdmin(address _token, address _admin)
        public
        onlyOwner
    {
        require(isAllowedToken[_token] == true, "Token not allowed.");
        allowedTokensData[_token].admin = _admin;
    }

    function setAllowedTokenRewardToken(address _token, address _reward_token)
        public
        onlyOwner
    {
        require(isAllowedToken[_token] == true, "Token not allowed.");
        allowedTokensData[_token].rewardToken = _reward_token;
    }

    function setAllowedTokenPrice(address _token, uint256 _price)
        public
        onlyOwner
    {
        require(isAllowedToken[_token] == true, "Token not allowed.");
        allowedTokensData[_token].price = _price;
    }

    function updateAllowedTokenRewardBalance(
        address _token,
        uint256 _amount,
        string memory _action
    ) public {
        require(isAllowedToken[_token] == true, "Token not allowed.");
        require(
            allowedTokensData[_token].admin == msg.sender,
            "Only the token admin can do this."
        );
        require(_amount > 0, "Amount must be greater than zero.");
        if (
            keccak256(abi.encodePacked(_action)) ==
            keccak256(abi.encodePacked("add"))
        ) {
            require(
                IERC20(_token).balanceOf(msg.sender) >= _amount,
                "Insufficient token balance."
            );
            IERC20(_token).transferFrom(msg.sender, address(this), _amount);
            allowedTokensData[_token].balance += _amount;
        }
        if (
            keccak256(abi.encodePacked(_action)) ==
            keccak256(abi.encodePacked("remove"))
        ) {
            require(
                allowedTokensData[_token].balance >= _amount,
                "Amount is greater than token balance."
            );
            IERC20(_token).transfer(msg.sender, _amount);
            allowedTokensData[_token].balance -= _amount;
        }
    }

    function updateStakingData(
        address _token,
        address _staker,
        uint256 _amount,
        string memory _action
    ) internal {
        if (_staker == address(0x0)) _staker = msg.sender;
        require(_amount > 0, "Amount must be greater than zero.");
        if (
            keccak256(abi.encodePacked(_action)) ==
            keccak256(abi.encodePacked("stake"))
        ) {
            require(
                isStakableAllowedToken[_token] == true,
                "Token not stakable."
            );
            require(
                IERC20(_token).balanceOf(_staker) >= _amount,
                "Insufficient token balance."
            );
            IERC20(_token).transferFrom(_staker, address(this), _amount);
            if (stakingData[_token][_staker].balance == 0) {
                if (stakersUniqueTokensStaked[_staker] == 0) {
                    stakers.push(_staker);
                    isStaker[_staker] = true;
                }
                stakersUniqueTokensStaked[_staker]++;
                stakingData[_token][_staker].rewardToken = _token;
            }
            stakingData[_token][_staker].balance += _amount;
        }
        if (
            keccak256(abi.encodePacked(_action)) ==
            keccak256(abi.encodePacked("unstake"))
        ) {
            require(
                stakingData[_token][_staker].balance >= _amount,
                "Amount is greater than token staking balance."
            );
            IERC20(_token).transfer(_staker, _amount);
            if (stakingData[_token][_staker].balance == _amount) {
                if (stakersUniqueTokensStaked[_staker] == 1) {
                    delete isStaker[_staker];
                    removeFrom(stakers, _staker);
                }
                stakersUniqueTokensStaked[_staker]--;
            }
            stakingData[_token][_staker].balance -= _amount;
        }
    }

    function updateStakersRewardToken(
        address _staker,
        address _token,
        address _reward_token
    ) public {
        require(isAllowedToken[_token] == true, "Token not allowed.");
        require(isAllowedToken[_reward_token] == true, "Token not allowed.");
        stakingData[_token][_staker].rewardToken = _reward_token;
    }

    function rewardStakers() public onlyOwner {
        for (
            uint256 allowedTokensIndex = 0;
            allowedTokensIndex < allowedTokens.length;
            allowedTokensIndex++
        ) {
            address token = allowedTokens[allowedTokensIndex];
            uint256 tokenPrice = allowedTokensData[token].price;
            for (
                uint256 stakersIndex = 0;
                stakersIndex < stakers.length;
                stakersIndex++
            ) {
                address staker = stakers[stakersIndex];
                uint256 stakerTokenBalance = stakingData[token][staker].balance;
                uint256 stakerReward = (stakerTokenBalance * tokenPrice) /
                    (100 / interestRate);
            }
        }
    }

    function withdrawReward(address _token, uint256 _amount) public {
        require(_amount > 0, "Amount must be greater than zero.");
        require(
            stakingData[_token][msg.sender].rewardBalance >= _amount,
            "Amount is greater than token reward balance."
        );
        IERC20(_token).transfer(msg.sender, _amount);
        stakingData[_token][msg.sender].rewardBalance -= _amount;
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
