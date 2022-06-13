// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./SavvyFinanceFarm.sol";

library SavvyFinanceFarmLibrary {
    function toWei(uint256 _number) public pure returns (uint256) {
        return _number * (10**18);
    }

    function fromWei(uint256 _number) public pure returns (uint256) {
        return _number / (10**18);
    }

    function secondsToYears(uint256 _seconds) public pure returns (uint256) {
        return fromWei(_seconds * (0.0000000317098 * (10**18)));
    }

    function calculatePercentage(uint256 _percentageValue, uint256 _totalAmount)
        public
        pure
        returns (uint256)
    {
        return (_totalAmount / toWei(100)) * _percentageValue;
    }

    function calculateStakingReward(
        SavvyFinanceFarm farm,
        address _token,
        address _staker
    )
        public
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        if (!farm.tokenExists(_token)) return (0, 0, 0, 0, 0);
        if (!farm.stakerExists(_staker)) return (0, 0, 0, 0, 0);

        uint256 tokenPrice = farm.getTokenData(_token).price;
        uint256 stakingBalance = farm
            .getTokenStakerData(_token, _staker)
            .stakingBalance;
        uint256 stakingValue = fromWei(stakingBalance * tokenPrice);
        if (stakingValue <= 0) return (0, 0, 0, 0, 0);

        uint256 stakingApr = farm.getTokenData(_token).stakingApr;
        uint256 stakingRewardRate = stakingApr / 100;
        uint256 stakingTimestampLastRewarded = farm
            .getTokenStakerData(_token, _staker)
            .timestampLastRewarded;
        uint256 stakingTimestampStarted = stakingTimestampLastRewarded != 0
            ? stakingTimestampLastRewarded
            : farm.getTokenStakerData(_token, _staker).timestampAdded;
        uint256 stakingTimestampEnded = block.timestamp;
        uint256 stakingDurationInSeconds = toWei(
            stakingTimestampEnded - stakingTimestampStarted
        );
        uint256 stakingDurationInYears = secondsToYears(
            stakingDurationInSeconds
        );
        uint256 stakingRewardValue = (stakingValue *
            stakingRewardRate *
            stakingDurationInYears) / (10**36);

        return (
            stakingRewardValue,
            stakingDurationInSeconds,
            stakingApr,
            stakingBalance,
            tokenPrice
        );
    }
}
