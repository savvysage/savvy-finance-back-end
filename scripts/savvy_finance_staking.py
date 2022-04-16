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
    savvy_finance = deploy_savvy_finance()
    savvy_finance_staking = deploy_savvy_finance_staking()
    tokens = get_tokens()
    tokens.append(savvy_finance.address)
    add_allowed_tokens(savvy_finance_staking, tokens)
    stake_amount = web3.toWei(10000, "ether")
    savvy_finance.approve(savvy_finance_staking.address, stake_amount).wait(1)
    savvy_finance_staking.stakeToken(savvy_finance.address, stake_amount).wait(1)

    savvy_finance_2 = deploy_savvy_finance()
    add_allowed_tokens(savvy_finance_staking, [savvy_finance_2.address])
    stake_amount_2 = web3.toWei(10000, "ether")
    savvy_finance_2.approve(savvy_finance_staking.address, stake_amount_2).wait(1)
    savvy_finance_staking.stakeToken(savvy_finance_2.address, stake_amount_2).wait(1)

    unstake_amount = web3.toWei(10000, "ether")
    savvy_finance_staking.unstakeToken(savvy_finance.address, unstake_amount).wait(1)
