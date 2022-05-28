// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract SavvyFinanceFarm is Ownable, AccessControl {
    address constant ZERO_ADDRESS = 0x0000000000000000000000000000000000000000;
    address public developmentWallet;
    uint256 public minimumStakingFee;
    uint256 public maximumStakingFee;
    uint256 public minimumStakingApr;
    uint256 public maximumStakingApr;
    mapping(address => bool) public isExcludedFromFees;
    mapping(uint256 => string) public tokenTypeNumberToName;

    address[] public tokens;
    struct TokenDetails {
        bool isActive;
        string name;
        uint256 _type;
        uint256 balance;
        uint256 price;
        uint256 stakeFee;
        uint256 unstakeFee;
        uint256 stakingApr;
        address rewardToken;
        address admin;
        uint256 timestampAdded;
        uint256 timestampLastUpdated;
    }
    mapping(address => TokenDetails) public tokensData;

    address[] public stakers;
    struct StakerDetails {
        bool isActive;
        uint256 uniqueTokensStaked;
        uint256 timestampAdded;
        uint256 timestampLastUpdated;
    }
    mapping(address => StakerDetails) public stakersData;

    struct StakerRewardDetails {
        uint256 id;
        address token;
        address rewardToken;
        uint256 rewardAmount;
        uint256 timestampAdded;
        uint256 timestampLastUpdated;
    }
    mapping(address => StakerRewardDetails[]) public stakersRewardsData;

    struct StakingDetails {
        uint256 balance;
        address rewardToken;
        uint256 timestampAdded;
        uint256 timestampLastUpdated;
    }
    // token => staker => StakingDetails
    mapping(address => mapping(address => StakingDetails)) public stakingData;

    struct StakingRewardDetails {
        uint256 balance;
        uint256 timestampAdded;
        uint256 timestampLastUpdated;
    }
    // reward_token => staker => StakingRewardDetails
    mapping(address => mapping(address => StakingRewardDetails))
        public stakingRewardsData;

    event Stake(address indexed staker, address indexed token, uint256 amount);
    event Unstake(
        address indexed staker,
        address indexed token,
        uint256 amount
    );
    event WithdrawStakingReward(
        address indexed staker,
        address indexed reward_token,
        uint256 amount
    );

    // constructor() {
    //     developmentWallet = _msgSender();
    //     minimumStakingFee = 0;
    //     maximumStakingFee = toWei(10);
    //     minimumStakingApr = toWei(50);
    //     maximumStakingApr = toWei(1000);
    //     _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
    // }

    function initialize() external {
        developmentWallet = _msgSender();
        minimumStakingFee = 0;
        maximumStakingFee = toWei(10);
        minimumStakingApr = toWei(50);
        maximumStakingApr = toWei(1000);
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _transferOwnership(_msgSender());
    }

    function toRole(address a) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(a));
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

    function tokenExists(address _token) public view returns (bool) {
        for (uint256 tokenIndex = 0; tokenIndex < tokens.length; tokenIndex++) {
            if (tokens[tokenIndex] == _token) return true;
        }
        return false;
    }

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

    function getTokens() public view returns (address[] memory) {
        return tokens;
    }

    function getTokenValue(address _token) public view returns (uint256) {
        return tokensData[_token].balance * tokensData[_token].price;
    }

    function getStakers() public view returns (address[] memory) {
        return stakers;
    }

    function getStakerRewardsData(address _staker)
        public
        view
        returns (StakerRewardDetails[] memory)
    {
        return stakersRewardsData[_staker];
    }

    function setDevelopmentWallet(address _developmentWallet) public onlyOwner {
        developmentWallet = _developmentWallet;
    }

    function setStakingFeeDetails(
        uint256 _minimumStakingFee,
        uint256 _maximumStakingFee
    ) public onlyOwner {
        minimumStakingFee = _minimumStakingFee;
        maximumStakingFee = _maximumStakingFee;
    }

    function setStakingAprDetails(
        uint256 _minimumStakingApr,
        uint256 _maximumStakingApr
    ) public onlyOwner {
        minimumStakingApr = _minimumStakingApr;
        maximumStakingApr = _maximumStakingApr;
    }

    function excludeFromFees(address _address) public onlyOwner {
        isExcludedFromFees[_address] = true;
    }

    function includeInFees(address _address) public onlyOwner {
        isExcludedFromFees[_address] = false;
    }

    function setTokenTypeNumberToName(uint256 _number, string memory _name)
        public
        onlyOwner
    {
        tokenTypeNumberToName[_number] = _name;
    }

    function addToken(
        address _token,
        string memory _name,
        uint256 _type,
        uint256 _stakeFee,
        uint256 _unstakeFee,
        uint256 _stakingApr,
        address _reward_token,
        address _admin
    ) public onlyOwner {
        require(!tokenExists(_token), "Token already exists.");
        _setupRole(toRole(_token), _msgSender());
        tokens.push(_token);
        tokensData[_token].name = _name;
        tokensData[_token]._type = _type;
        tokensData[_token].timestampAdded = block.timestamp;
        setTokenStakingFees(
            _token,
            _stakeFee == 0 ? toWei(1) : _stakeFee,
            _unstakeFee == 0 ? toWei(1) : _unstakeFee
        );
        setTokenStakingApr(_token, _stakingApr == 0 ? toWei(365) : _stakingApr);
        setTokenRewardToken(
            _token,
            _reward_token == address(0x0) ? _token : _reward_token
        );
        setTokenAdmin(_token, _admin == address(0x0) ? _msgSender() : _admin);
    }

    function activateToken(address _token) public onlyOwner {
        require(tokenExists(_token), "Token does not exist.");
        tokensData[_token].isActive = true;
    }

    function deactivateToken(address _token) public onlyOwner {
        require(tokenExists(_token), "Token does not exist.");
        tokensData[_token].isActive = false;
    }

    function setTokenName(address _token, string memory _name)
        public
        onlyOwner
    {
        require(tokenExists(_token), "Token does not exist.");
        tokensData[_token].name = _name;
        tokensData[_token].timestampLastUpdated = block.timestamp;
    }

    function setTokenPrice(address _token, uint256 _price) public onlyOwner {
        require(tokenExists(_token), "Token does not exist.");
        tokensData[_token].price = _price;
        tokensData[_token].timestampLastUpdated = block.timestamp;
    }

    function setTokenAdmin(address _token, address _admin) public onlyOwner {
        require(tokenExists(_token), "Token does not exist.");
        if (tokensData[_token].admin != owner())
            revokeRole(toRole(_token), tokensData[_token].admin);
        tokensData[_token].admin = _admin;
        tokensData[_token].timestampLastUpdated = block.timestamp;
        grantRole(toRole(_token), tokensData[_token].admin);
    }

    function setTokenStakingFees(
        address _token,
        uint256 _stakeFee,
        uint256 _unstakeFee
    ) public onlyOwner {
        setTokenStakeFee(_token, _stakeFee);
        setTokenUnstakeFee(_token, _unstakeFee);
    }

    function setTokenStakeFee(address _token, uint256 _stakeFee)
        public
        onlyOwner
    {
        require(tokenExists(_token), "Token does not exist.");
        require(
            _stakeFee >= minimumStakingFee && _stakeFee <= maximumStakingFee,
            string(
                abi.encodePacked(
                    "Stake fee must be between",
                    fromWei(minimumStakingFee),
                    "and",
                    fromWei(maximumStakingFee),
                    "."
                )
            )
        );
        tokensData[_token].stakeFee = _stakeFee;
        tokensData[_token].timestampLastUpdated = block.timestamp;
    }

    function setTokenUnstakeFee(address _token, uint256 _unstakeFee)
        public
        onlyOwner
    {
        require(tokenExists(_token), "Token does not exist.");
        require(
            _unstakeFee >= minimumStakingFee &&
                _unstakeFee <= maximumStakingFee,
            string(
                abi.encodePacked(
                    "Unstake fee must be between",
                    fromWei(minimumStakingFee),
                    "and",
                    fromWei(maximumStakingFee),
                    "."
                )
            )
        );
        tokensData[_token].unstakeFee = _unstakeFee;
        tokensData[_token].timestampLastUpdated = block.timestamp;
    }

    function setTokenStakingApr(address _token, uint256 _stakingApr)
        public
        onlyRole(toRole(_token))
    {
        require(tokenExists(_token), "Token does not exist.");
        require(
            _stakingApr >= minimumStakingApr &&
                _stakingApr <= maximumStakingApr,
            string(
                abi.encodePacked(
                    "Staking APR must be between",
                    fromWei(minimumStakingApr),
                    "and",
                    fromWei(maximumStakingApr),
                    "."
                )
            )
        );
        tokensData[_token].stakingApr = _stakingApr;
        tokensData[_token].timestampLastUpdated = block.timestamp;
    }

    function setTokenRewardToken(address _token, address _reward_token)
        public
        onlyRole(toRole(_token))
        onlyRole(toRole(_reward_token))
    {
        require(tokenExists(_token), "Token does not exist.");
        require(tokenExists(_reward_token), "Reward token does not exist.");
        tokensData[_token].rewardToken = _reward_token;
        tokensData[_token].timestampLastUpdated = block.timestamp;
    }

    function depositToken(address _token, uint256 _amount)
        public
        onlyRole(toRole(_token))
    {
        require(tokenExists(_token), "Token does not exist.");
        require(_amount > 0, "Amount must be greater than zero.");
        require(
            IERC20(_token).balanceOf(_msgSender()) >= _amount,
            "Insufficient token balance."
        );
        IERC20(_token).transferFrom(_msgSender(), address(this), _amount);
        tokensData[_token].balance += _amount;
    }

    function withdrawToken(address _token, uint256 _amount)
        public
        onlyRole(toRole(_token))
    {
        require(tokenExists(_token), "Token does not exist.");
        require(_amount > 0, "Amount must be greater than zero.");
        require(
            tokensData[_token].balance >= _amount,
            "Amount is greater than token balance."
        );
        tokensData[_token].balance -= _amount;
        IERC20(_token).transfer(_msgSender(), _amount);
    }

    function stakeToken(address _token, uint256 _amount) public {
        require(tokensData[_token].isActive, "Token not active.");
        require(_amount > 0, "Amount must be greater than zero.");
        require(
            IERC20(_token).balanceOf(_msgSender()) >= _amount,
            "Insufficient token balance."
        );

        uint256 stakeFee = (_amount / toWei(100)) * tokensData[_token].stakeFee;
        uint256 stakeAmount;
        if (stakeFee == 0 || isExcludedFromFees[_msgSender()]) {
            stakeAmount = _amount;
        } else {
            IERC20(_token).transferFrom(
                _msgSender(),
                developmentWallet,
                stakeFee
            );
            stakeAmount = _amount - stakeFee;
        }
        IERC20(_token).transferFrom(_msgSender(), address(this), stakeAmount);

        if (stakingData[_token][_msgSender()].balance == 0) {
            if (stakersData[_msgSender()].uniqueTokensStaked == 0) {
                if (!stakerExists(_msgSender())) stakers.push(_msgSender());
                stakersData[_msgSender()].isActive = true;
            }
            stakersData[_msgSender()].uniqueTokensStaked++;
            stakersData[_msgSender()].timestampAdded == 0
                ? stakersData[_msgSender()].timestampAdded = block.timestamp
                : stakersData[_msgSender()].timestampLastUpdated = block
                .timestamp;
            stakingData[_token][_msgSender()].rewardToken = _token;
        } else {
            rewardStaker(_msgSender(), _token);
        }

        stakingData[_token][_msgSender()].balance += stakeAmount;
        stakingData[_token][_msgSender()].timestampAdded == 0
            ? stakingData[_token][_msgSender()].timestampAdded = block.timestamp
            : stakingData[_token][_msgSender()].timestampLastUpdated = block
            .timestamp;
        emit Stake(_msgSender(), _token, stakeAmount);
    }

    function unstakeToken(address _token, uint256 _amount) public {
        // require(tokensData[_token].isActive, "Token not active.");
        require(_amount > 0, "Amount must be greater than zero.");
        require(
            stakingData[_token][_msgSender()].balance >= _amount,
            "Amount is greater than token staking balance."
        );

        rewardStaker(_msgSender(), _token);

        if (stakingData[_token][_msgSender()].balance == _amount) {
            if (stakersData[_msgSender()].uniqueTokensStaked == 1) {
                stakersData[_msgSender()].isActive = false;
            }
            stakersData[_msgSender()].uniqueTokensStaked--;
            stakersData[_msgSender()].timestampLastUpdated = block.timestamp;
        }

        stakingData[_token][_msgSender()].balance -= _amount;
        stakingData[_token][_msgSender()].timestampAdded == 0
            ? stakingData[_token][_msgSender()].timestampAdded = block.timestamp
            : stakingData[_token][_msgSender()].timestampLastUpdated = block
            .timestamp;

        uint256 unstakeFee = (_amount / toWei(100)) *
            tokensData[_token].unstakeFee;
        uint256 unstakeAmount;
        if (unstakeFee == 0 || isExcludedFromFees[_msgSender()]) {
            unstakeAmount = _amount;
        } else {
            IERC20(_token).transfer(developmentWallet, unstakeFee);
            unstakeAmount = _amount - unstakeFee;
        }
        IERC20(_token).transfer(_msgSender(), unstakeAmount);
        emit Unstake(_msgSender(), _token, unstakeAmount);
    }

    function withdrawStakingReward(address _reward_token, uint256 _amount)
        public
    {
        require(_amount > 0, "Amount must be greater than zero.");
        require(
            stakingRewardsData[_reward_token][_msgSender()].balance >= _amount,
            "Amount is greater than reward token balance."
        );
        stakingRewardsData[_reward_token][_msgSender()].balance -= _amount;
        IERC20(_reward_token).transfer(_msgSender(), _amount);
        emit WithdrawStakingReward(_msgSender(), _reward_token, _amount);
    }

    function setStakingRewardToken(address _token, address _reward_token)
        public
    {
        setStakerRewardToken(_msgSender(), _token, _reward_token, true);
    }

    function setStakerRewardToken(
        address _staker,
        address _token,
        address _reward_token,
        bool validate
    ) internal returns (address) {
        if (validate) {
            require(
                stakersData[_msgSender()].isActive,
                "Staker does not have this token staked."
            );
            require(tokensData[_token].isActive, "Token not active.");
            require(
                tokensData[_reward_token].isActive,
                "Reward token not active."
            );
        }
        stakingData[_token][_staker].rewardToken = _reward_token;
        return stakingData[_token][_staker].rewardToken;
    }

    function calculateStakerRewardValue(address _staker, address _token)
        internal
        view
        returns (uint256)
    {
        if (!tokenExists(_token)) return 0;
        TokenDetails memory tokenData = tokensData[_token];
        if (!stakerExists(_staker)) return 0;
        StakingDetails memory stakerData = stakingData[_token][_staker];
        if (stakerData.balance <= 0) return 0;

        uint256 stakerValue = fromWei(stakerData.balance * tokenData.price);
        uint256 rate = tokenData.stakingApr / 100;
        uint256 timestampStarted = stakerData.timestampLastUpdated != 0
            ? stakerData.timestampLastUpdated
            : stakerData.timestampAdded;
        uint256 timestampEnded = block.timestamp;
        uint256 timeInSeconds = toWei(timestampEnded - timestampStarted);
        uint256 timeInYears = secondsToYears(timeInSeconds);

        return (stakerValue * rate * timeInYears) / (10**36);
    }

    function rewardStaker(address _staker, address _token) internal {
        if (!tokensData[_token].isActive) return;
        if (!stakersData[_staker].isActive) return;

        TokenDetails memory tokenData = tokensData[_token];
        StakingDetails memory stakingData1 = stakingData[_token][_staker];
        if (stakingData1.balance <= 0) return;

        if (!tokensData[stakingData1.rewardToken].isActive) {
            if (stakingData1.rewardToken == tokenData.rewardToken) return;
            stakingData1.rewardToken = setStakerRewardToken(
                _staker,
                _token,
                tokenData.rewardToken,
                false
            );
            if (!tokensData[stakingData1.rewardToken].isActive) return;
        }

        uint256 stakerRewardValue = calculateStakerRewardValue(_staker, _token);
        uint256 stakerRewardTokenValue = getTokenValue(
            stakingData1.rewardToken
        );

        if (stakerRewardTokenValue < stakerRewardValue) {
            if (stakingData1.rewardToken == tokenData.rewardToken) {
                deactivateToken(_token);
                return;
            }
            stakingData1.rewardToken = setStakerRewardToken(
                _staker,
                _token,
                tokenData.rewardToken,
                false
            );
            stakerRewardTokenValue = getTokenValue(stakingData1.rewardToken);
            if (stakerRewardTokenValue < stakerRewardValue) {
                deactivateToken(_token);
                return;
            }
        }

        uint256 stakerRewardTokenAmount = toWei(
            stakerRewardValue / tokensData[stakingData1.rewardToken].price
        );
        if (stakerRewardTokenAmount <= 0) return;

        tokensData[stakingData1.rewardToken].balance -= stakerRewardTokenAmount;
        tokensData[stakingData1.rewardToken].timestampLastUpdated = block
            .timestamp;
        stakingRewardsData[stakingData1.rewardToken][_staker]
            .balance += stakerRewardTokenAmount;
        stakingRewardsData[stakingData1.rewardToken][_staker]
            .timestampLastUpdated = block.timestamp;

        StakerRewardDetails memory stakerRewardData;
        stakerRewardData.id = stakersRewardsData[_staker].length;
        stakerRewardData.token = _token;
        stakerRewardData.rewardToken = stakingData1.rewardToken;
        stakerRewardData.rewardAmount = stakerRewardTokenAmount;
        stakerRewardData.timestampAdded = block.timestamp;
        stakersRewardsData[_staker].push(stakerRewardData);
    }

    function rewardStakers() public onlyOwner {
        for (uint256 tokenIndex = 0; tokenIndex < tokens.length; tokenIndex++) {
            address token = tokens[tokenIndex];

            for (
                uint256 stakerIndex = 0;
                stakerIndex < stakers.length;
                stakerIndex++
            ) {
                address staker = stakers[stakerIndex];

                rewardStaker(staker, token);
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
