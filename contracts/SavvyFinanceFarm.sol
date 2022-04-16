// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract SavvyFinanceFarm is Ownable {
    mapping(address => mapping(address => uint256)) public stakingData;
    mapping(address => uint256) public stakersToUniqueTokensStaked;
    address[] public stakers;
    address[] public allowedTokens;

    function stakeToken(address _token, uint256 _amount) public {
        require(tokenIsAllowed(_token), "You can't stake this token.");
        require(_amount > 0, "Amount must be greater than zero.");
        require(
            IERC20(_token).balanceOf(msg.sender) >= _amount,
            "Insufficient balance."
        );
        IERC20(_token).transferFrom(msg.sender, address(this), _amount);
        updateStakersData(msg.sender, _token, "stake");
        stakingData[_token][msg.sender] += _amount;
    }

    function unstakeToken(address _token, uint256 _amount) public {
        require(_amount > 0, "Amount must be greater than zero.");
        require(
            stakingData[_token][msg.sender] >= _amount,
            "Amount is greater than staking balance."
        );
        IERC20(_token).transfer(msg.sender, _amount);
        stakingData[_token][msg.sender] -= _amount;
        updateStakersData(msg.sender, _token, "unstake");
    }

    function updateStakersData(
        address _staker,
        address _token,
        string memory _action
    ) internal {
        if (stakingData[_token][_staker] <= 0) {
            if (
                keccak256(abi.encodePacked(_action)) ==
                keccak256(abi.encodePacked("stake"))
            ) {
                stakersToUniqueTokensStaked[_staker]++;

                if (stakersToUniqueTokensStaked[_staker] == 1) {
                    stakers.push(msg.sender);
                }
            }

            if (
                keccak256(abi.encodePacked(_action)) ==
                keccak256(abi.encodePacked("unstake"))
            ) {
                stakersToUniqueTokensStaked[_staker]--;

                if (stakersToUniqueTokensStaked[_staker] == 0) {
                    removeFrom(stakers, _staker);
                }
            }
        }
    }

    function rewardStakers() public onlyOwner {}

    function tokenIsAllowed(address _token) public view returns (bool) {
        for (
            uint256 allowedTokensIndex = 0;
            allowedTokensIndex < allowedTokens.length;
            allowedTokensIndex++
        ) {
            if (allowedTokens[allowedTokensIndex] == _token) {
                return true;
            }
        }
        return false;
    }

    function addAllowedToken(address _token) public onlyOwner {
        allowedTokens.push(_token);
    }

    function removeAllowedToken(address _token) public onlyOwner {
        removeFrom(allowedTokens, _token);
    }

    function removeFrom(address[] storage _array, address _value) internal {
        for (uint256 arrayIndex = 0; arrayIndex < _array.length; arrayIndex++) {
            if (_array[arrayIndex] == _value) {
                // move to last index
                _array[arrayIndex] = _array[_array.length - 1];
                // delete last index
                _array.pop();
            }
        }
    }
}
