from brownie import (
    ProxyAdmin,
    TransparentUpgradeableProxy,
    SavvyFinance,
    SavvyFinanceUpgradeable,
    SavvyFinanceFarm,
    Contract,
    network,
    config,
    web3,
)
from scripts.common import (
    print_json,
    get_account,
    get_address,
    get_token_price,
    get_lp_token_price,
    get_contract_address,
    get_contract,
    encode_function_data,
)
import os, shutil, yaml, json


def get_tokens():
    return {
        "wbnb_token": get_contract("wbnb_token").address,
        "busd_token": get_contract("busd_token").address,
        "link_token": get_contract("link_token").address,
    }


def deploy_proxy_admin(account=get_account()):
    return ProxyAdmin.deploy({"from": account})


def deploy_transparent_upgradeable_proxy(
    proxy_admin, contract, *args, account=get_account()
):
    # If we want an intializer function we can add
    # `initializer=box.store, 1`
    # to simulate the initializer being the `store` function
    # with a `newValue` of 1
    # box_encoded_initializer_function = encode_function_data()
    # box_encoded_initializer_function = encode_function_data(initializer=box.store, 1)
    encoded_initializer_function = encode_function_data(
        *args, initializer=contract.initialize
    )
    return TransparentUpgradeableProxy.deploy(
        contract.address,
        proxy_admin.address,
        encoded_initializer_function,
        {"from": account},
    )


def deploy_savvy_finance(account=get_account()):
    return SavvyFinance.deploy(
        web3.toWei(1000000, "ether"),
        {"from": account},
        publish_source=config["networks"][network.show_active()].get("verify", False),
    )


def deploy_savvy_finance_upgradeable(account=get_account()):
    return SavvyFinanceUpgradeable.deploy({"from": account})


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


def exclude_from_fees(contract, address, account=get_account()):
    contract.excludeFromFees(address, {"from": account}).wait(1)


def include_in_fees(contract, address, account=get_account()):
    contract.includeInFees(address, {"from": account}).wait(1)


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


def copy_to_front_end(src, dest):
    if os.path.exists(dest):
        shutil.rmtree(dest)
    shutil.copytree(src, dest)


def update_front_end():
    copy_to_front_end("./build", "./front_end/src/chain-info")
    with open("brownie-config.yaml", "r") as brownie_config:
        config_dict = yaml.load(brownie_config, Loader=yaml.FullLoader)
        with open(
            "./front_end/src/brownie-config.json", "w"
        ) as frontend_brownie_config:
            json.dump(config_dict, frontend_brownie_config)
    print("Front end updated!")


def main():
    proxy_admin = ProxyAdmin[-1]
    savvy_finance = SavvyFinance[-1]
    savvy_finance_proxy = TransparentUpgradeableProxy[-2]
    savvy_finance_farm = SavvyFinanceFarm[-1]
    savvy_finance_farm_proxy = TransparentUpgradeableProxy[-1]

    # proxy_admin = deploy_proxy_admin()

    # savvy_finance = deploy_savvy_finance()
    # savvy_finance = deploy_savvy_finance_upgradeable()
    # savvy_finance_proxy = deploy_transparent_upgradeable_proxy(
    #     proxy_admin, savvy_finance, web3.toWei(1000000, "ether")
    # )
    proxy_savvy_finance = Contract.from_abi(
        savvy_finance._name, savvy_finance_proxy.address, savvy_finance.abi
    )

    # savvy_finance_farm = deploy_savvy_finance_farm()
    # savvy_finance_farm_proxy = deploy_transparent_upgradeable_proxy(
    #     proxy_admin, savvy_finance_farm
    # )
    proxy_savvy_finance_farm = Contract.from_abi(
        savvy_finance_farm._name,
        savvy_finance_farm_proxy.address,
        savvy_finance_farm.abi,
    )
    # print_json(SavvyFinanceUpgradeable.get_verification_info())

    tokens = get_tokens()
    tokens["svf_token"] = proxy_savvy_finance.address
    # add_tokens(proxy_savvy_finance_farm, tokens)
    # set_tokens_prices(proxy_savvy_finance_farm, tokens)
    # activate_tokens(proxy_savvy_finance_farm, tokens)

    # print(proxy_admin.owner(), get_account().address)
    # print(proxy_admin.getProxyAdmin(savvy_finance_proxy), proxy_admin.address)
    # print(proxy_admin.getProxyAdmin(savvy_finance_farm_proxy), proxy_admin.address)
    # print(proxy_admin.getProxyImplementation(savvy_finance_proxy), savvy_finance.address)
    # print(proxy_admin.getProxyImplementation(savvy_finance_farm_proxy), savvy_finance_farm.address)
    # print(savvy_finance_farm.developmentWallet())
    # print(proxy_savvy_finance_farm.developmentWallet())
    # print(savvy_finance_farm.toRole(tokens["svf_token"]))
    # print(proxy_savvy_finance_farm.toRole(tokens["svf_token"]))

    # add_tokens(proxy_savvy_finance_farm, {"svf_token": tokens["svf_token"]})
    # set_tokens_prices(proxy_savvy_finance_farm, {"svf_token": tokens["svf_token"]})
    # deposit_token(proxy_savvy_finance_farm, proxy_savvy_finance, 20000)
    # withdraw_token(proxy_savvy_finance_farm, proxy_savvy_finance, 10000)
    # activate_tokens(proxy_savvy_finance_farm, {"svf_token": tokens["svf_token"]})
    # exclude_from_fees(proxy_savvy_finance_farm, get_account().address)
    # stake_token(proxy_savvy_finance_farm, proxy_savvy_finance, 1000)
    # unstake_token(proxy_savvy_finance_farm, proxy_savvy_finance, 500)
    # stake_token(proxy_savvy_finance_farm, proxy_savvy_finance, 500)

    # print(
    #     proxy_savvy_finance_farm.calculateStakerRewardValue(
    #         get_account().address, tokens["svf_token"]
    #     )
    # )
    # print(
    #     web3.fromWei(
    #         proxy_savvy_finance_farm.calculateStakerRewardValue(
    #             get_account().address, tokens["svf_token"]
    #         ),
    #         "ether",
    #     )
    # )
    # proxy_savvy_finance_farm.rewardStakers({"from": get_account()}).wait(1)
    # proxy_savvy_finance_farm.rewardStakers({"from": get_account()}).wait(1)

    print_json(
        get_tokens_data(proxy_savvy_finance_farm, {"svf_token": tokens["svf_token"]})
    )
    print_json(get_stakers_data(proxy_savvy_finance_farm))
    print_json(get_stakers_rewards_data(proxy_savvy_finance_farm))
    print_json(
        get_staking_data(proxy_savvy_finance_farm, {"svf_token": tokens["svf_token"]})
    )
    print_json(
        get_staking_rewards_data(
            proxy_savvy_finance_farm, {"svf_token": tokens["svf_token"]}
        )
    )
    print(
        web3.fromWei(
            proxy_savvy_finance.balanceOf(proxy_savvy_finance_farm.address), "ether"
        )
    )
    print(web3.fromWei(proxy_savvy_finance.balanceOf(get_account().address), "ether"))
