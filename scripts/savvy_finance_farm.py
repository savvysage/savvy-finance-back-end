from brownie import SavvyFinance, SavvyFinanceFarm, network, config, web3
from scripts.common import (
    get_account,
    get_address,
    get_token_price,
    get_lp_token_price,
    get_contract_address,
    get_contract,
)


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


def get_tokens():
    return {
        "wbnb_token": get_contract("wbnb_token").address,
        "busd_token": get_contract("busd_token").address,
        "link_token": get_contract("link_token").address,
    }


def get_tokens_data(contract, tokens, account=get_account()):
    # tokens = contract.getTokens()
    token_data = {}
    for token_name in tokens:
        token = tokens[token_name]
        token_data[token_name] = contract.tokensData(token, {"from": account})
    return token_data


def add_tokens(contract, tokens, account=get_account()):
    for token_name in tokens:
        token = tokens[token_name]
        token_type = 0
        token_staking_apr = 0
        token_reward_token = get_address("zero")
        token_admin = get_address("zero")
        contract.addToken(
            token,
            token_type,
            token_staking_apr,
            token_reward_token,
            token_admin,
            {"from": account},
        ).wait(1)


# def activate_tokens(contract, tokens, account=get_account()):
#     for token_name in tokens:
#         token = tokens[token_name]
#         contract.activateToken(token, {"from": account}).wait(1)


# def deactivate_tokens(contract, tokens, account=get_account()):
#     for token_name in tokens:
#         token = tokens[token_name]
#         contract.deactivateToken(token, {"from": account}).wait(1)


def set_tokens_prices(contract, tokens, account=get_account()):
    # tokens = contract.getTokens()
    for token_name in tokens:
        token = tokens[token_name]
        token_price = web3.toWei(
            get_token_price(get_contract_address(token_name, "bsc-main")), "ether"
        )
        contract.setTokenPrice(token, token_price, {"from": account}).wait(1)


def main():
    savvy_finance = SavvyFinance[-1]
    savvy_finance_farm = SavvyFinanceFarm[-1]

    # savvy_finance = deploy_savvy_finance()
    # savvy_finance_farm = deploy_savvy_finance_farm()

    tokens = get_tokens()
    tokens["svf_token"] = savvy_finance.address
    # add_tokens(savvy_finance_farm, tokens)

    # savvy_finance_farm.activateToken(
    #     tokens["wbnb_token"], {"from": get_account()}
    # ).wait(1)
    # wbnb_token_price = web3.toWei(
    #     get_token_price(get_contract_address("wbnb_token", "bsc-main")), "ether"
    # )
    # savvy_finance_farm.setTokenPrice(
    #     tokens["wbnb_token"], wbnb_token_price, {"from": get_account()}
    # ).wait(1)
    # print(savvy_finance_farm.tokensData(tokens["wbnb_token"]))

    set_tokens_prices(savvy_finance_farm, tokens)
    print(get_tokens_data(savvy_finance_farm, tokens))
    print(get_token_price(get_contract_address("link_token", "bsc-main")))

    # set_token_price(savvy_finance_farm, {"wbnb_token": tokens["wbnb_token"]})
    # token_price = savvy_finance_farm.tokensData(tokens["wbnb_token"])[1]
    # print(token_price)
    # print(web3.fromWei(token_price, "ether"))


# savvy_finance_farm.setTokenPrice(
#     tokens[3], web3.toWei(10, "ether"), {"from": get_account()}
# ).wait(1)
# savvy_finance_farm.setTokenInterestRate(
#     tokens[3], web3.toWei(1, "ether"), {"from": get_account()}
# ).wait(1)
# deposit_amount = web3.toWei(20000, "ether")
# savvy_finance.approve(
#     savvy_finance_farm.address, deposit_amount, {"from": get_account()}
# ).wait(1)
# savvy_finance_farm.depositToken(
#     tokens[3], deposit_amount, {"from": get_account()}
# ).wait(1)
# withdraw_amount = web3.toWei(10000, "ether")
# savvy_finance_farm.withdrawToken(
#     tokens[3], withdraw_amount, {"from": get_account()}
# ).wait(1)

# stake_amount = web3.toWei(1000, "ether")
# savvy_finance.approve(
#     savvy_finance_farm.address, stake_amount, {"from": get_account()}
# ).wait(1)
# savvy_finance_farm.stakeToken(
#     tokens[3], stake_amount, {"from": get_account()}
# ).wait(1)
# unstake_amount = web3.toWei(500, "ether")
# savvy_finance_farm.unstakeToken(
#     tokens[3], unstake_amount, {"from": get_account()}
# ).wait(1)
# savvy_finance_farm.rewardStakers().wait(1)

###############################################

# weth_token = get_contract("weth_token")

# add_tokens(savvy_finance_farm, [weth_token.address])
# savvy_finance_farm.setAllowedTokenPriceFeed(
#     weth_token.address,
#     "0x8A753747A1Fa494EC906cE90E9f37563A8AF630e",
#     {"from": get_account()},
# ).wait(1)

# stake_amount = web3.toWei(0.1, "ether")
# weth_token.approve(
#     savvy_finance_farm.address, stake_amount, {"from": get_account()}
# ).wait(1)
# savvy_finance_farm.stakeToken(
#     weth_token.address, stake_amount, get_address("zero"), {"from": get_account()}
# ).wait(1)

# savvy_finance.transfer(
#     savvy_finance_farm.address,
#     web3.toWei(1000, "ether"),
#     {"from": get_account(), "gas_limit": 1000000},
# ).wait(1)
# get_account().transfer(
#     savvy_finance_farm.address, web3.toWei(0.01, "ether"), {"gas_limit": 1000000}
# ).wait(1)

# savvy_finance_farm.rewardStakers(
#     {"from": get_account(), "gas_limit": 1000000}
# ).wait(1)

# my_staking_reward = savvy_finance_farm.stakersRewards(get_account().address)
# print(my_staking_reward)
# print(my_staking_reward / 10 ** 18)
