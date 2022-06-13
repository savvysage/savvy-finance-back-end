// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./SavvyFinanceFarmToken.sol";
import "./SavvyFinanceFarmStaker.sol";
import {SavvyFinanceFarmLibrary as Lib} from "./SavvyFinanceFarmLibrary.sol";

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
    // event WithdrawStakingReward(
    //     address indexed staker,
    //     address indexed reward_token,
    //     uint256 amount
    // );

    function getTokenStakerData(address _token, address _staker)
        public
        view
        returns (TokenStakerDetails memory)
    {
        return tokensStakersData[_token][_staker];
    }

    function getStakingValue(address _token, address _staker)
        public
        view
        returns (uint256)
    {
        return
            _fromWei(
                tokensStakersData[_token][_staker].stakingBalance *
                    tokensData[_token].price
            );
    }

    function setStakingRewardToken(address _token, address _reward_token)
        public
    {
        _setStakingRewardToken(_msgSender(), _token, _reward_token, true);
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

        // emit Unstake(_msgSender(), _token, unstakeAmount);
    }

    function claimStakingReward(address _token) public {
        require(tokensData[_token].isActive, "Token not active.");
        _issueStakingReward(_token, _msgSender(), ["claim staking reward", ""]);
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
        // emit WithdrawStakingReward(_msgSender(), _reward_token, _amount);
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

    function _issueStakingReward(
        address _token,
        address _staker,
        string[2] memory _triggeredBy
    ) internal {
        if (!tokensData[_token].isActive) return;
        if (!stakersData[_staker].isActive) return;
        address tokenRewardToken = tokensData[_token].rewardToken;
        address stakingRewardToken = tokensStakersData[_token][_staker]
            .stakingRewardToken;

        (
            uint256 stakingRewardValue,
            uint256 stakingDurationInSeconds,
            uint256 stakingApr,
            uint256 stakingBalance,
            uint256 tokenPrice
        ) = Lib.calculateStakingReward(this, _token, _staker);
        if (stakingRewardValue == 0) return;

        if (!tokensData[stakingRewardToken].isActive) {
            if (stakingRewardToken == tokenRewardToken) return;
            stakingRewardToken = _setStakingRewardToken(
                _staker,
                _token,
                tokenRewardToken,
                false
            );
            if (!tokensData[stakingRewardToken].isActive) return;
        }

        uint256 stakingRewardTokenRewardValue = getTokenRewardValue(
            stakingRewardToken
        );
        if (stakingRewardTokenRewardValue < stakingRewardValue) {
            if (stakingRewardToken == tokenRewardToken) {
                deactivateToken(_token);
                return;
            }
            stakingRewardToken = _setStakingRewardToken(
                _staker,
                _token,
                tokenRewardToken,
                false
            );
            stakingRewardTokenRewardValue = getTokenRewardValue(
                stakingRewardToken
            );
            if (stakingRewardTokenRewardValue < stakingRewardValue) {
                deactivateToken(_token);
                return;
            }
        }

        uint256 stakingRewardTokenPrice = tokensData[stakingRewardToken].price;
        uint256 stakingRewardTokenAmount = _toWei(stakingRewardValue) /
            stakingRewardTokenPrice;
        if (stakingRewardTokenAmount <= 0) return;

        tokensData[stakingRewardToken]
            .rewardBalance -= stakingRewardTokenAmount;
        tokensData[stakingRewardToken].timestampLastUpdated = block.timestamp;
        tokensStakersData[stakingRewardToken][_staker]
            .rewardBalance += stakingRewardTokenAmount;
        tokensStakersData[stakingRewardToken][_staker]
            .timestampLastUpdated = block.timestamp;
        tokensStakersData[_token][_staker].timestampLastRewarded = block
            .timestamp;

        TokenStakerRewardDetails memory tokenStakerRewardData;
        tokenStakerRewardData.id = tokensStakersData[_token][_staker]
            .stakingRewards
            .length;
        tokenStakerRewardData.staker = _staker;
        tokenStakerRewardData.rewardToken = stakingRewardToken;
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

        // emit IssueStakingReward(_staker, _token, tokenStakerRewardData);
    }

    // function _issueStakingReward(
    //     address _token,
    //     address _staker,
    //     string[2] memory _triggeredBy
    // ) internal {
    //     if (!tokensData[_token].isActive) return;
    //     if (!stakersData[_staker].isActive) return;

    //     TokenDetails memory tokenData = tokensData[_token];
    //     TokenStakerDetails memory tokenStakerData = tokensStakersData[_token][
    //         _staker
    //     ];
    //     if (tokenStakerData.stakingBalance <= 0) return;

    //     if (!tokensData[tokenStakerData.stakingRewardToken].isActive) {
    //         if (tokenStakerData.stakingRewardToken == tokenData.rewardToken)
    //             return;
    //         tokenStakerData.stakingRewardToken = _setStakingRewardToken(
    //             _staker,
    //             _token,
    //             tokenData.rewardToken,
    //             false
    //         );
    //         if (!tokensData[tokenStakerData.stakingRewardToken].isActive)
    //             return;
    //     }

    //     (
    //         uint256 stakingRewardValue,
    //         uint256 stakingDurationInSeconds,
    //         uint256 stakingApr,
    //         uint256 stakingBalance,
    //         uint256 tokenPrice
    //     ) = _calculateStakingReward(_token, _staker);
    //     if (stakingRewardValue == 0) return;

    //     uint256 stakerRewardTokenRewardValue = getTokenRewardValue(
    //         tokenStakerData.stakingRewardToken
    //     );
    //     if (stakerRewardTokenRewardValue < stakingRewardValue) {
    //         if (tokenStakerData.stakingRewardToken == tokenData.rewardToken) {
    //             deactivateToken(_token);
    //             return;
    //         }
    //         tokenStakerData.stakingRewardToken = _setStakingRewardToken(
    //             _staker,
    //             _token,
    //             tokenData.rewardToken,
    //             false
    //         );
    //         stakerRewardTokenRewardValue = getTokenRewardValue(
    //             tokenStakerData.stakingRewardToken
    //         );
    //         if (stakerRewardTokenRewardValue < stakingRewardValue) {
    //             deactivateToken(_token);
    //             return;
    //         }
    //     }

    //     uint256 stakingRewardTokenPrice = tokensData[
    //         tokenStakerData.stakingRewardToken
    //     ].price;
    //     uint256 stakingRewardTokenAmount = _toWei(stakingRewardValue) /
    //         stakingRewardTokenPrice;
    //     if (stakingRewardTokenAmount <= 0) return;

    //     tokensData[tokenStakerData.stakingRewardToken]
    //         .rewardBalance -= stakingRewardTokenAmount;
    //     tokensData[tokenStakerData.stakingRewardToken]
    //         .timestampLastUpdated = block.timestamp;
    //     tokensStakersData[tokenStakerData.stakingRewardToken][_staker]
    //         .rewardBalance += stakingRewardTokenAmount;
    //     tokensStakersData[tokenStakerData.stakingRewardToken][_staker]
    //         .timestampLastUpdated = block.timestamp;
    //     tokensStakersData[_token][_staker].timestampLastRewarded = block
    //         .timestamp;

    //     TokenStakerRewardDetails memory tokenStakerRewardData;
    //     tokenStakerRewardData.id = tokensStakersData[_token][_staker]
    //         .stakingRewards
    //         .length;
    //     tokenStakerRewardData.staker = _staker;
    //     tokenStakerRewardData.rewardToken = tokenStakerData.stakingRewardToken;
    //     tokenStakerRewardData.rewardTokenPrice = stakingRewardTokenPrice;
    //     tokenStakerRewardData.rewardTokenAmount = stakingRewardTokenAmount;
    //     tokenStakerRewardData.stakedToken = _token;
    //     tokenStakerRewardData.stakedTokenPrice = tokenPrice;
    //     tokenStakerRewardData.stakedTokenAmount = stakingBalance;
    //     tokenStakerRewardData.stakingApr = stakingApr;
    //     tokenStakerRewardData
    //         .stakingDurationInSeconds = stakingDurationInSeconds;
    //     tokenStakerRewardData.triggeredBy = _triggeredBy;
    //     tokenStakerRewardData.timestampAdded = block.timestamp;
    //     tokensStakersData[_token][_staker].stakingRewards.push(
    //         tokenStakerRewardData
    //     );

    //     // emit IssueStakingReward(_staker, _token, tokenStakerRewardData);
    // }
}
