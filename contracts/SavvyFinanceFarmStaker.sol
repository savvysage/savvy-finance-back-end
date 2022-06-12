// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./SavvyFinanceFarmBase.sol";

contract SavvyFinanceFarmStaker is SavvyFinanceFarmBase {
    address[] public stakers;
    struct StakerDetails {
        // uint256 index;
        bool isActive;
        uint256 uniqueTokensStaked;
        uint256 timestampAdded;
        uint256 timestampLastUpdated;
    }
    mapping(address => StakerDetails) public stakersData;

    function stakerExists(address _staker) public view returns (bool) {
        for (
            uint256 stakerIndex = 0;
            stakerIndex < stakers.length;
            stakerIndex++
        ) {
            if (stakers[stakerIndex] == _staker) return true;
        }
        return false;
    }

    function getStakers() public view returns (address[] memory) {
        return stakers;
    }

    function getStakerData(address _staker)
        public
        view
        returns (StakerDetails memory)
    {
        return stakersData[_staker];
    }

    function _addStaker(address _staker) internal {
        require(!stakerExists(_staker), "Staker already exists.");
        // uint256 index = stakers.length;
        stakers.push(_staker);
        // stakersData[_staker].index = index;
        stakersData[_staker].timestampAdded = block.timestamp;
    }
}
