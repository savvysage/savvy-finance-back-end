// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library SavvyFinanceFarmLibrary {
    function toRole(address _token) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(_token));
    }

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
}
