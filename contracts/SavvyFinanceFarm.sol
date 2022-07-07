// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./SavvyFinanceFarmToken.sol";
import "./SavvyFinanceFarmStaker.sol";

contract SavvyFinanceFarm is SavvyFinanceFarmToken, SavvyFinanceFarmStaker {
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

    // event Stake(address indexed staker, address indexed token, uint256 amount);
    // event Unstake(
    //     address indexed staker,
    //     address indexed token,
    //     uint256 amount
    // );
    // event IssueStakingReward(
    //     address indexed staker,
    //     address indexed token,
    //     TokenStakerRewardDetails rewardData
    // );
    // event withdrawRewardToken(
    //     address indexed staker,
    //     address indexed reward_token,
    //     uint256 amount
    // );

    function initialize() public override {
        super.initialize();
        configDex(
            0,
            DexDetails(
                "PancakeSwap V2",
                0x10ED43C718714eb63d5aA57B78B54704E256024E,
                0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56
            )
        );
        configTokenCategory(0, "BEP20");
        configTokenCategory(1, "Cake-LP");
    }

    function getTokenStakerData(address _token, address _staker)
        public
        view
        returns (TokenStakerDetails memory)
    {
        return tokensStakersData[_token][_staker];
    }

    function changeStakingRewardToken(address _token, address _reward_token)
        public
        returns (address stakingRewardToken)
    {
        require(tokenExists(_token), "Token does not exist.");
        require(tokenExists(_reward_token), "Reward token does not exist.");

        if (_token != _reward_token) {
            require(
                tokensData[_token].hasMultiTokenRewards,
                "Token does not have multi token rewards."
            );
            require(
                tokensData[_reward_token].hasMultiTokenRewards,
                "Reward token does not have multi token rewards."
            );
        }

        if (!stakerExists(_msgSender())) _addStaker(_msgSender());
        tokensStakersData[_token][_msgSender()]
            .stakingRewardToken = _reward_token;
        tokensStakersData[_token][_msgSender()].timestampLastUpdated = block
            .timestamp;

        return tokensStakersData[_token][_msgSender()].stakingRewardToken;
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

        // emit Stake(_msgSender(), _token, stakeAmount);
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
        tokensStakersData[_token][_msgSender()].timestampLastUpdated = block
            .timestamp;
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

        // emit Unstake(_msgSender(), _token, unstakeAmount);
    }

    function claimStakingReward(address _token) public {
        require(tokensData[_token].isActive, "Token not active.");
        _issueStakingReward(_token, _msgSender(), ["claim staking reward", ""]);
    }

    function withdrawRewardToken(address _reward_token, uint256 _amount)
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
        // emit withdrawRewardToken(_msgSender(), _reward_token, _amount);
    }

    function _issueReward(
        address _rewardToken,
        uint256 _rewardTokenAmount,
        address _receiver
    ) internal {
        tokensData[_rewardToken].rewardBalance -= _rewardTokenAmount;
        tokensData[_rewardToken].timestampLastUpdated = block.timestamp;
        tokensStakersData[_rewardToken][_receiver]
            .rewardBalance += _rewardTokenAmount;
        tokensStakersData[_rewardToken][_receiver].timestampLastUpdated = block
            .timestamp;
    }

    function _issueStakingReward(
        address _token,
        address _staker,
        string[2] memory _triggeredBy
    ) internal {
        if (!tokensData[_token].isActive) return;
        if (!stakersData[_staker].isActive) return;

        uint256 tokenPrice = Lib.getTokenPrice(
            address(this),
            _token,
            tokensData[_token].category
        );
        (
            uint256 stakingRewardAmount,
            uint256 stakingDurationInSeconds,
            uint256 stakingApr,
            uint256 stakingAmount
        ) = Lib.calculateStakingReward(address(this), _token, _staker);
        if (stakingRewardAmount == 0) return;
        address tokenRewardToken = tokensData[_token].rewardToken;
        if (!tokensData[tokenRewardToken].isActive) return;

        address rewardToken = tokenRewardToken;
        uint256 rewardTokenPrice = Lib.getTokenPrice(
            address(this),
            rewardToken,
            tokensData[rewardToken].category
        );
        uint256 rewardTokenAmount = Lib.getTokenValue(
            address(this),
            _token,
            stakingRewardAmount
        ) / rewardTokenPrice;
        if (tokensData[rewardToken].rewardBalance < rewardTokenAmount) {
            deactivateToken(_token);
            return;
        }

        // {
        //     // if staking reward token is different from token reward token,
        //     // staking reward token admin receives the reward in token reward token
        //     // to pay back equivalent in staking reward token, basically swapping
        //     address stakingRewardToken = tokensStakersData[_token][_staker]
        //         .stakingRewardToken;
        //     if (stakingRewardToken != rewardToken) {
        //         if (tokensData[stakingRewardToken].isActive) {
        //             uint256 stakingRewardTokenRewardValue = getTokenRewardValue(
        //                 stakingRewardToken
        //             );
        //             if (!(stakingRewardTokenRewardValue < stakingRewardValue)) {
        //                 // staking reward token admin receives the reward
        //                 // in token reward token
        //                 address stakingRewardTokenAdmin = tokensData[
        //                     stakingRewardToken
        //                 ].admin;
        //                 _issueReward(
        //                     rewardToken,
        //                     rewardTokenAmount,
        //                     stakingRewardTokenAdmin
        //                 );
        //                 // change reward token to staking reward token for payback
        //                 rewardToken = stakingRewardToken;
        //                 rewardTokenPrice = Lib.getTokenPrice(
        //                     address(this),
        //                     rewardToken,
        //                     tokensData[rewardToken].category
        //                 );
        //                 rewardTokenAmount =
        //                     _toWei(stakingRewardValue) /
        //                     rewardTokenPrice;
        //             }
        //         }
        //     }
        // }

        _issueReward(rewardToken, rewardTokenAmount, _staker);
        tokensStakersData[_token][_staker].timestampLastRewarded = block
            .timestamp;

        TokenStakerRewardDetails memory tokenStakerRewardData;
        tokenStakerRewardData.id = tokensStakersData[_token][_staker]
            .stakingRewards
            .length;
        tokenStakerRewardData.staker = _staker;
        tokenStakerRewardData.rewardToken = rewardToken;
        tokenStakerRewardData.rewardTokenPrice = rewardTokenPrice;
        tokenStakerRewardData.rewardTokenAmount = rewardTokenAmount;
        tokenStakerRewardData.stakedToken = _token;
        tokenStakerRewardData.stakedTokenPrice = tokenPrice;
        tokenStakerRewardData.stakedTokenAmount = stakingAmount;
        tokenStakerRewardData.stakingApr = stakingApr;
        tokenStakerRewardData
            .stakingDurationInSeconds = stakingDurationInSeconds;
        tokenStakerRewardData.triggeredBy = _triggeredBy;
        tokenStakerRewardData.timestampAdded = block.timestamp;
        tokensStakersData[_token][_staker].stakingRewards.push(
            tokenStakerRewardData
        );

        // emit IssueStakingReward(_staker, _token, tokenStakerRewardData);
    }
}
