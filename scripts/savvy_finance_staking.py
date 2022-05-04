from brownie import SavvyFinance, SavvyFinanceStaking, network, config, web3
from scripts.common import get_account, get_contract


def deploy_savvy_finance(account=get_account()):
    return SavvyFinance.deploy(
        web3.toWei(1000000, "ether"),
        {"from": account},
        publish_source=config["networks"][network.show_active()].get("verify", False),
    )


def deploy_savvy_finance_staking(account=get_account()):
    return SavvyFinanceStaking.deploy(
        {"from": account},
        publish_source=config["networks"][network.show_active()].get("verify", False),
    )


def get_eth_tokens():
    return [
        get_contract("weth_token").address,
        get_contract("dai_token").address,
        get_contract("link_token").address,
    ]


def get_bsc_tokens():
    return [
        get_contract("wbnb_token").address,
        get_contract("busd_token").address,
        get_contract("link_token").address,
    ]


def add_tokens(contract, tokens, account=get_account()):
    for token in tokens:
        contract.addToken(token, config["addresses"]["zero"], {"from": account}).wait(1)


def activate_tokens(contract, tokens, account=get_account()):
    for token in tokens:
        contract.activateToken(token, {"from": account}).wait(1)


def main():
    savvy_finance = SavvyFinance[-1]
    savvy_finance_staking = SavvyFinanceStaking[-1]

    # savvy_finance = deploy_savvy_finance()
    # savvy_finance_staking = deploy_savvy_finance_staking()

    tokens = get_bsc_tokens()
    tokens.append(savvy_finance.address)
    add_tokens(savvy_finance_staking, tokens)
    activate_tokens(savvy_finance_staking, tokens)

    savvy_finance_staking.setTokenPrice(
        tokens[3], web3.toWei(10, "ether"), {"from": get_account()}
    ).wait(1)
    savvy_finance_staking.setTokenInterestRate(
        tokens[3], web3.toWei(1, "ether"), {"from": get_account()}
    ).wait(1)
    deposit_amount = web3.toWei(20000, "ether")
    savvy_finance.approve(
        savvy_finance_staking.address, deposit_amount, {"from": get_account()}
    ).wait(1)
    savvy_finance_staking.depositToken(
        tokens[3], deposit_amount, {"from": get_account()}
    ).wait(1)
    withdraw_amount = web3.toWei(10000, "ether")
    savvy_finance_staking.withdrawToken(
        tokens[3], withdraw_amount, {"from": get_account()}
    ).wait(1)

    stake_amount = web3.toWei(1000, "ether")
    savvy_finance.approve(
        savvy_finance_staking.address, stake_amount, {"from": get_account()}
    ).wait(1)
    savvy_finance_staking.stakeToken(
        tokens[3], stake_amount, {"from": get_account()}
    ).wait(1)
    unstake_amount = web3.toWei(500, "ether")
    savvy_finance_staking.unstakeToken(
        tokens[3], unstake_amount, {"from": get_account()}
    ).wait(1)
    # savvy_finance_staking.rewardStakers().wait(1)

    # weth_token = get_contract("weth_token")

    # add_tokens(savvy_finance_staking, [weth_token.address])
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
