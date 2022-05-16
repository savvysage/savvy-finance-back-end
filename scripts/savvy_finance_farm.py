from brownie import SavvyFinance, SavvyFinanceFarm, network, config, web3
from scripts.common import (
    print_json,
    get_account,
    get_address,
    get_token_price,
    get_lp_token_price,
    get_contract_address,
    get_contract,
)


def get_tokens():
    return {
        "wbnb_token": get_contract("wbnb_token").address,
        "busd_token": get_contract("busd_token").address,
        "link_token": get_contract("link_token").address,
    }


def deploy_savvy_finance(account=get_account()):
    return SavvyFinance.deploy(
        web3.toWei(1000000, "ether"),
        {"from": account},
        publish_source=config["networks"][network.show_active()].get("verify", False),
    )


def deploy_savvy_finance_farm(account=get_account()):
    return SavvyFinanceFarm.deploy(
        {"from": account},
        publish_source=config["networks"][network.show_active()].get("verify", False),
    )


def get_tokens_data(contract, tokens, account=get_account()):
    # tokens = contract.getTokens()
    tokens_data = {}
    for token_name in tokens:
        token = tokens[token_name]
        token_data = list(contract.tokensData(token, {"from": account}))
        token_data[1] = float(web3.fromWei(token_data[1], "ether"))
        token_data[2] = float(web3.fromWei(token_data[2], "ether"))
        token_data[3] = float(web3.fromWei(token_data[3], "ether"))
        token_data[4] = float(web3.fromWei(token_data[4], "ether"))
        token_data[5] = float(web3.fromWei(token_data[5], "ether"))
        token_is_active = contract.tokenIsActive(token)
        token_data.insert(0, token_is_active)
        tokens_data[token_name] = token_data
    return tokens_data


def get_stakers_data(contract, account=get_account()):
    stakers = contract.getStakers()
    stakers_data = {}
    for staker in stakers:
        staker_data = list(contract.stakersData(staker, {"from": account}))
        staker_is_active = contract.stakerIsActive(staker)
        staker_data.insert(0, staker_is_active)
        stakers_data[staker] = staker_data
    return stakers_data


def get_stakers_rewards_data(contract, account=get_account()):
    stakers = contract.getStakers()
    stakers_rewards_data = {}
    for staker in stakers:
        staker_rewards_data = list(
            contract.getStakerRewardsData(staker, {"from": account})
        )
        for index, staker_reward_data in enumerate(staker_rewards_data):
            staker_reward_data = list(staker_reward_data)
            staker_reward_data[3] = float(web3.fromWei(staker_reward_data[3], "ether"))
            staker_rewards_data[index] = staker_reward_data
        stakers_rewards_data[staker] = staker_rewards_data
    return stakers_rewards_data


def get_staking_data(contract, tokens, account=get_account()):
    # tokens = contract.getTokens()
    stakers = contract.getStakers()
    staking_data = {}
    for token_name in tokens:
        token = tokens[token_name]
        token_staking_data = {}
        for staker in stakers:
            token_staker_data = list(
                contract.stakingData(token, staker, {"from": account})
            )
            token_staker_data[0] = float(web3.fromWei(token_staker_data[0], "ether"))
            token_staking_data[staker] = token_staker_data
        staking_data[token_name] = token_staking_data
    return staking_data


def get_staking_rewards_data(contract, tokens, account=get_account()):
    # tokens = contract.getTokens()
    stakers = contract.getStakers()
    staking_rewards_data = {}
    for token_name in tokens:
        token = tokens[token_name]
        token_staking_rewards_data = {}
        for staker in stakers:
            token_staker_rewards_data = list(
                contract.stakingRewardsData(token, staker, {"from": account})
            )
            token_staker_rewards_data[0] = float(
                web3.fromWei(token_staker_rewards_data[0], "ether")
            )
            token_staking_rewards_data[staker] = token_staker_rewards_data
        staking_rewards_data[token_name] = token_staking_rewards_data
    return staking_rewards_data


def exclude_staker_from_fees(contract, staker, account=get_account()):
    contract.excludeStakerFromFees(staker, {"from": account}).wait(1)


def include_staker_in_fees(contract, staker, account=get_account()):
    contract.includeStakerInFees(staker, {"from": account}).wait(1)


def add_tokens(contract, tokens, account=get_account()):
    for token_name in tokens:
        token = tokens[token_name]
        token_type = 0
        token_stake_fee = 0
        token_unstake_fee = 0
        token_staking_apr = 0
        token_reward_token = get_address("zero")
        token_admin = get_address("zero")
        contract.addToken(
            token,
            token_type,
            token_stake_fee,
            token_unstake_fee,
            token_staking_apr,
            token_reward_token,
            token_admin,
            {"from": account},
        ).wait(1)


def activate_tokens(contract, tokens, account=get_account()):
    for token_name in tokens:
        token = tokens[token_name]
        contract.activateToken(token, {"from": account}).wait(1)


def deactivate_tokens(contract, tokens, account=get_account()):
    for token_name in tokens:
        token = tokens[token_name]
        contract.deactivateToken(token, {"from": account}).wait(1)


def set_tokens_prices(contract, tokens, account=get_account()):
    # tokens = contract.getTokens()
    for token_name in tokens:
        token = tokens[token_name]
        token_price = web3.toWei(
            get_token_price(get_contract_address(token_name, "bsc-main")), "ether"
        )
        contract.setTokenPrice(token, token_price, {"from": account}).wait(1)


def set_lp_tokens_prices(contract, tokens, account=get_account()):
    # tokens = contract.getTokens()
    for token_name in tokens:
        token = tokens[token_name]
        token_price = web3.toWei(
            get_lp_token_price(get_contract_address(token_name, "bsc-main")), "ether"
        )
        contract.setTokenPrice(token, token_price, {"from": account}).wait(1)


def deposit_token(contract, token, amount, account=get_account()):
    amount = web3.toWei(amount, "ether")
    token.approve(contract.address, amount, {"from": account}).wait(1)
    contract.depositToken(token.address, amount, {"from": account}).wait(1)


def withdraw_token(contract, token, amount, account=get_account()):
    amount = web3.toWei(amount, "ether")
    contract.withdrawToken(token.address, amount, {"from": account}).wait(1)


def stake_token(contract, token, amount, account=get_account()):
    amount = web3.toWei(amount, "ether")
    token.approve(contract.address, amount, {"from": account}).wait(1)
    contract.stakeToken(token.address, amount, {"from": account}).wait(1)


def unstake_token(contract, token, amount, account=get_account()):
    amount = web3.toWei(amount, "ether")
    contract.unstakeToken(token.address, amount, {"from": account}).wait(1)


def main():
    # savvy_finance = SavvyFinance[-1]
    # savvy_finance_farm = SavvyFinanceFarm[-1]

    savvy_finance = deploy_savvy_finance()
    savvy_finance_farm = deploy_savvy_finance_farm()

    tokens = get_tokens()
    tokens["svf_token"] = savvy_finance.address
    # add_tokens(savvy_finance_farm, tokens)
    # set_tokens_prices(savvy_finance_farm, tokens)
    # activate_tokens(savvy_finance_farm, tokens)

    add_tokens(savvy_finance_farm, {"svf_token": tokens["svf_token"]})
    set_tokens_prices(savvy_finance_farm, {"svf_token": tokens["svf_token"]})
    deposit_token(savvy_finance_farm, savvy_finance, 20000)
    withdraw_token(savvy_finance_farm, savvy_finance, 10000)
    activate_tokens(savvy_finance_farm, {"svf_token": tokens["svf_token"]})
    exclude_staker_from_fees(savvy_finance_farm, get_account().address)
    stake_token(savvy_finance_farm, savvy_finance, 1000)
    unstake_token(savvy_finance_farm, savvy_finance, 500)
    stake_token(savvy_finance_farm, savvy_finance, 500)

    savvy_finance_farm.rewardStakers({"from": get_account()}).wait(1)

    print_json(get_tokens_data(savvy_finance_farm, {"svf_token": tokens["svf_token"]}))
    print_json(get_stakers_data(savvy_finance_farm))
    print_json(get_stakers_rewards_data(savvy_finance_farm))
    print_json(get_staking_data(savvy_finance_farm, {"svf_token": tokens["svf_token"]}))
    print_json(
        get_staking_rewards_data(savvy_finance_farm, {"svf_token": tokens["svf_token"]})
    )
    print(web3.fromWei(savvy_finance.balanceOf(savvy_finance_farm.address), "ether"))
    print(web3.fromWei(savvy_finance.balanceOf(get_account().address), "ether"))
