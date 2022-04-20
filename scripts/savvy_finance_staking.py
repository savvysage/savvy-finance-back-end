from brownie import SavvyFinance, SavvyFinanceStaking, network, config, web3
from scripts.common import get_account, get_contract


def deploy_savvy_finance(account=get_account()):
    return SavvyFinance.deploy(
        web3.toWei(1000000, "ether"),
        {"from": account},
        publish_source=config["networks"][network.show_active()].get("verify", False),
    )


def deploy_savvy_finance_staking(reward_token_address, account=get_account()):
    return SavvyFinanceStaking.deploy(
        reward_token_address,
        {"from": account},
        publish_source=config["networks"][network.show_active()].get("verify", False),
    )


def get_tokens():
    return [
        get_contract("weth_token").address,
        get_contract("dai_token").address,
        get_contract("link_token").address,
    ]


def add_allowed_tokens(contract, tokens):
    for token in tokens:
        contract.addAllowedToken(token).wait(1)


def remove_allowed_tokens(contract, tokens):
    for token in tokens:
        contract.removeAllowedToken(token).wait(1)


def main():
    savvy_finance = SavvyFinance[-1]
    savvy_finance_2 = SavvyFinance[-2]
    savvy_finance_staking = SavvyFinanceStaking[-1]

    # savvy_finance = deploy_savvy_finance()
    # savvy_finance_staking = deploy_savvy_finance_staking(savvy_finance.address)

    # tokens = get_tokens()
    # tokens.append(savvy_finance.address)
    # add_allowed_tokens(savvy_finance_staking, tokens)

    # stake_amount = web3.toWei(10000, "ether")
    # savvy_finance.approve(savvy_finance_staking.address, stake_amount).wait(1)
    # savvy_finance_staking.stakeToken(savvy_finance.address, stake_amount, get_address("null0")).wait(1)

    # savvy_finance_2 = deploy_savvy_finance()
    # add_allowed_tokens(savvy_finance_staking, [savvy_finance_2.address])
    # stake_amount_2 = web3.toWei(10000, "ether")
    # savvy_finance_2.approve(savvy_finance_staking.address, stake_amount_2).wait(1)
    # savvy_finance_staking.stakeToken(savvy_finance_2.address, stake_amount_2, get_address("null0")).wait(1)

    # unstake_amount_2 = web3.toWei(10000, "ether")
    # savvy_finance_staking.unstakeToken(savvy_finance_2.address, unstake_amount_2, get_address("null0")).wait(
    #     1
    # )

    weth_token = get_contract("weth_token")

    # add_allowed_tokens(savvy_finance_staking, [weth_token.address])
    # savvy_finance_staking.setAllowedTokenPriceFeed(
    #     weth_token.address,
    #     "0x8A753747A1Fa494EC906cE90E9f37563A8AF630e",
    #     {"from": get_account()},
    # ).wait(1)

    # stake_amount = web3.toWei(0.1, "ether")
    # weth_token.approve(
    #     savvy_finance_staking.address, stake_amount, {"from": get_account()}
    # ).wait(1)
    # savvy_finance_staking.stakeToken(
    #     weth_token.address, stake_amount, get_address("null0"), {"from": get_account()}
    # ).wait(1)

    # savvy_finance.transfer(
    #     savvy_finance_staking.address,
    #     web3.toWei(1000, "ether"),
    #     {"from": get_account(), "gas_limit": 1000000},
    # ).wait(1)
    # get_account().transfer(
    #     savvy_finance_staking.address, web3.toWei(0.01, "ether"), {"gas_limit": 1000000}
    # ).wait(1)

    # savvy_finance_staking.rewardStakers(
    #     {"from": get_account(), "gas_limit": 1000000}
    # ).wait(1)

    # my_staking_reward = savvy_finance_staking.stakersRewards(get_account().address)
    # print(my_staking_reward)
    # print(my_staking_reward / 10 ** 18)
