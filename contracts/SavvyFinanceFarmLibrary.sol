// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./SavvyFinanceFarm.sol";
import "../interfaces/IERC20.sol";
import "../interfaces/IUniswapV2Factory.sol";
import "../interfaces/IUniswapV2Pair.sol";
import "../interfaces/IUniswapV2Router02.sol";

library SavvyFinanceFarmLibrary {
    address constant ZERO_ADDRESS = 0x0000000000000000000000000000000000000000;

    function toWei(uint256 _number) public pure returns (uint256) {
        return _number * (10**18);
    }

    function fromWei(uint256 _number) public pure returns (uint256) {
        return _number / (10**18);
    }

    function getTokenPrice(
        address _farm,
        address _token,
        uint256 _category
    ) public view returns (uint256) {
        uint256 priceInUsd;

        // for testing tokens with no liquidity
        // function should return 0 so set a price
        // priceInUsd = toWei(12);

        SavvyFinanceFarm farm = SavvyFinanceFarm(_farm);
        IUniswapV2Router02 router = IUniswapV2Router02(farm.getDex(0).router);

        if (_category == 0) {
            IUniswapV2Factory factory = IUniswapV2Factory(router.factory());
            address usdToken = farm.getDex(0).usdToken;
            address usdPair = factory.getPair(_token, usdToken);
            address wethToken = router.WETH();
            address wethPair = factory.getPair(_token, wethToken);

            address[] memory path = new address[](2);
            if (usdPair != ZERO_ADDRESS) {
                path[0] = _token;
                path[1] = usdToken;
                priceInUsd = router.getAmountsOut(toWei(1), path)[1];
            } else {
                if (wethPair != ZERO_ADDRESS) {
                    path[0] = _token;
                    path[1] = wethToken;
                    uint256 priceInWeth = router.getAmountsOut(toWei(1), path)[
                        1
                    ];

                    path[0] = wethToken;
                    path[1] = usdToken;
                    uint256 wethPriceInUsd = router.getAmountsOut(
                        toWei(1),
                        path
                    )[1];

                    priceInUsd = fromWei(priceInWeth * wethPriceInUsd);
                }
            }
        }

        if (_category == 1) {
            IUniswapV2Pair pair = IUniswapV2Pair(_token);
            if (
                keccak256(abi.encodePacked(pair.symbol())) ==
                keccak256(abi.encodePacked(farm.getTokenCategoryName(1)))
            ) {
                uint256 totalSupply = pair.totalSupply();
                address token0 = pair.token0();
                address token1 = pair.token1();
                (uint256 token0Reserve, uint256 token1Reserve, ) = pair
                    .getReserves();
                uint256 token0Price = getTokenPrice(_farm, token0, 0);
                uint256 token1Price = getTokenPrice(_farm, token1, 0);
                uint256 token0Value = token0Reserve * token0Price;
                uint256 token1Value = token1Reserve * token1Price;
                uint256 totalValue = token0Value + token1Value;
                priceInUsd = totalValue / totalSupply;
            }
        }

        return priceInUsd;
    }

    function getTokenValue(
        address _farm,
        address _token,
        uint256 _amount
    ) public view returns (uint256) {
        SavvyFinanceFarm farm = SavvyFinanceFarm(_farm);

        return
            fromWei(
                _amount *
                    getTokenPrice(
                        _farm,
                        _token,
                        farm.getTokenData(_token).category
                    )
            );
    }

    function getStakingValue(
        address _farm,
        address _token,
        address _staker
    ) public view returns (uint256) {
        SavvyFinanceFarm farm = SavvyFinanceFarm(_farm);

        return
            getTokenValue(
                _farm,
                _token,
                farm.getTokenStakerData(_token, _staker).stakingBalance
            );
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
        address _farm,
        address _token,
        address _staker
    )
        public
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        SavvyFinanceFarm farm = SavvyFinanceFarm(_farm);
        if (!farm.tokenExists(_token)) return (0, 0, 0, 0);
        if (!farm.stakerExists(_staker)) return (0, 0, 0, 0);

        uint256 stakingAmount = farm
            .getTokenStakerData(_token, _staker)
            .stakingBalance;
        if (stakingAmount <= 0) return (0, 0, 0, 0);

        uint256 stakingApr = farm.getTokenData(_token).stakingApr;
        uint256 stakingRewardRate = stakingApr / 100;
        uint256 stakingTimestampLastRewarded = farm
            .getTokenStakerData(_token, _staker)
            .timestampLastRewarded;
        uint256 stakingTimestampStarted = stakingTimestampLastRewarded != 0
            ? stakingTimestampLastRewarded
            : farm.getTokenStakerData(_token, _staker).timestampAdded;
        uint256 stakingTimestampEnded = block.timestamp + (60 * 60 * 24);
        uint256 stakingDurationInSeconds = toWei(
            stakingTimestampEnded - stakingTimestampStarted
        );
        uint256 stakingDurationInYears = secondsToYears(
            stakingDurationInSeconds
        );
        uint256 stakingRewardAmount = (stakingAmount *
            stakingRewardRate *
            stakingDurationInYears) / (10**36);

        return (
            stakingRewardAmount,
            stakingDurationInSeconds,
            stakingApr,
            stakingAmount
        );
    }
}
