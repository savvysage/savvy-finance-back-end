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
        "wbnb": get_contract("wbnb_token").address,
        "busd": get_contract("busd_token").address,
        "wbnb_busd": get_contract("wbnb_busd_lp_token").address,
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


def get_tokens_data(contract, tokens=None, account=get_account()):
    if not tokens:
        tokens = list(contract.getTokens())
    else:
        tokens = list(tokens.values())

    tokens_data = {}
    for token in tokens:
        token_data = list(contract.getTokenData(token))
        token_data[4] = float(web3.fromWei(token_data[4], "ether"))
        token_data[5] = float(web3.fromWei(token_data[5], "ether"))
        token_data[6] = float(web3.fromWei(token_data[6], "ether"))
        token_data[7] = float(web3.fromWei(token_data[7], "ether"))
        token_data[8] = float(web3.fromWei(token_data[8], "ether"))
        token_data[9] = float(web3.fromWei(token_data[9], "ether"))
        # token_data[10] = float(web3.fromWei(token_data[10], "ether"))
        tokens_data[token] = token_data
    return tokens_data


def get_stakers_data(contract, stakers=None, account=get_account()):
    if not stakers:
        stakers = list(contract.getStakers())

    stakers_data = {}
    for staker in stakers:
        staker_data = list(contract.getStakerData(staker))
        stakers_data[staker] = staker_data
    return stakers_data


def get_tokens_stakers_data(contract, tokens=None, stakers=None, account=get_account()):
    if not tokens:
        tokens = list(contract.getTokens())
    else:
        tokens = list(tokens.values())
    if not stakers:
        stakers = list(contract.getStakers())

    tokens_stakers_data = {}
    for token in tokens:
        token_stakers_data = {}
        for staker in stakers:
            token_staker_data = list(contract.getTokenStakerData(token, staker))
            token_staker_data[0] = float(web3.fromWei(token_staker_data[0], "ether"))
            token_staker_data[1] = float(web3.fromWei(token_staker_data[1], "ether"))
            token_staker_data[3] = list(token_staker_data[3])
            for index, staking_reward in enumerate(token_staker_data[3]):
                staking_reward = list(staking_reward)
                staking_reward[3] = float(web3.fromWei(staking_reward[3], "ether"))
                staking_reward[4] = float(web3.fromWei(staking_reward[4], "ether"))
                staking_reward[6] = float(web3.fromWei(staking_reward[6], "ether"))
                staking_reward[7] = float(web3.fromWei(staking_reward[7], "ether"))
                staking_reward[8] = float(web3.fromWei(staking_reward[8], "ether"))
                staking_reward[9] = list(staking_reward[9])
                token_staker_data[3][index] = staking_reward
            token_stakers_data[staker] = token_staker_data
        tokens_stakers_data[token] = token_stakers_data
    return tokens_stakers_data


def exclude_from_fees(contract, address, account=get_account()):
    contract.excludeFromFees(address, {"from": account}).wait(1)


def include_in_fees(contract, address, account=get_account()):
    contract.includeInFees(address, {"from": account}).wait(1)


def set_token_types(contract, types, account=get_account()):
    for index, type in enumerate(types):
        contract.setTokenTypeNumberToName(index, type, {"from": account}).wait(1)


def add_tokens(contract, tokens=get_tokens(), account=get_account()):
    for token_name in tokens:
        token = tokens[token_name]
        token_name_2 = token_name.replace("_", "-").upper()
        token_type = 0 if ("_" not in token_name) else 1
        token_stake_fee = 0
        token_unstake_fee = 0
        token_staking_apr = 0
        token_reward_token = get_address("zero")
        token_admin = get_address("zero")
        contract.addToken(
            token,
            token_name_2,
            token_type,
            token_stake_fee,
            token_unstake_fee,
            token_staking_apr,
            token_reward_token,
            token_admin,
            {"from": account},
        ).wait(1)
        print("Added " + token_name + " token.", "\n\n")


def activate_tokens(contract, tokens=get_tokens(), account=get_account()):
    for token_name in tokens:
        token = tokens[token_name]
        contract.activateToken(token, {"from": account}).wait(1)
        print("Activated " + token_name + " token.", "\n\n")


def deactivate_tokens(contract, tokens=get_tokens(), account=get_account()):
    for token_name in tokens:
        token = tokens[token_name]
        contract.deactivateToken(token, {"from": account}).wait(1)
        print("Deactivated " + token_name + " token.", "\n\n")


def enable_tokens_multi_reward(contract, tokens=get_tokens(), account=get_account()):
    for token_name in tokens:
        token = tokens[token_name]
        contract.enableTokenMultiReward(token, {"from": account}).wait(1)
        print("Enabled " + token_name + " token multi reward.", "\n\n")


def disable_tokens_multi_reward(contract, tokens=get_tokens(), account=get_account()):
    for token_name in tokens:
        token = tokens[token_name]
        contract.disableTokenMultiReward(token, {"from": account}).wait(1)
        print("Disabled " + token_name + " token multi reward.", "\n\n")


def set_tokens_prices(contract, tokens=get_tokens(), account=get_account()):
    # tokens = contract.getTokens()
    for token_name in tokens:
        token = tokens[token_name]
        token_price = web3.toWei(
            get_token_price(get_contract_address(token_name + "_token", "bsc-main"))
            if ("_" not in token_name)
            else get_lp_token_price(
                get_contract_address(token_name + "_lp_token"), "bsc-main"
            ),
            "ether",
        )
        contract.setTokenPrice(token, token_price, {"from": account}).wait(1)
        print("Updated " + token_name + " token price.", "\n\n")


def set_lp_tokens_prices(contract, tokens, account=get_account()):
    # tokens = contract.getTokens()
    for token_name in tokens:
        token = tokens[token_name]
        token_price = web3.toWei(
            get_lp_token_price(get_contract_address(token_name + "_token", "bsc-main")),
            "ether",
        )
        contract.setTokenPrice(token, token_price, {"from": account}).wait(1)
        print("Updated " + token_name + " token price.", "\n\n")


def deposit_token(contract, token_contract, amount, account=get_account()):
    amount2 = web3.toWei(amount, "ether")
    token_contract.approve(contract.address, amount2, {"from": account}).wait(1)
    contract.depositToken(token_contract.address, amount2, {"from": account}).wait(1)
    print("Deposited " + str(amount) + " " + token_contract.symbol() + ".", "\n\n")


def withdraw_token(contract, token_contract, amount, account=get_account()):
    amount2 = web3.toWei(amount, "ether")
    contract.withdrawToken(token_contract.address, amount2, {"from": account}).wait(1)
    print("Withdrew " + str(amount) + " " + token_contract.symbol() + ".", "\n\n")


def stake_token(contract, token_contract, amount, account=get_account()):
    amount2 = web3.toWei(amount, "ether")
    token_contract.approve(contract.address, amount2, {"from": account}).wait(1)
    contract.stakeToken(token_contract.address, amount2, {"from": account}).wait(1)
    print("Staked " + str(amount) + " " + token_contract.symbol() + ".", "\n\n")


def unstake_token(contract, token_contract, amount, account=get_account()):
    amount2 = web3.toWei(amount, "ether")
    contract.unstakeToken(token_contract.address, amount2, {"from": account}).wait(1)
    print("Unstaked " + str(amount) + " " + token_contract.symbol() + ".", "\n\n")


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


def get_contracts(deploy=None):
    if deploy == "all":
        proxy_admin = deploy_proxy_admin()
        savvy_finance = deploy_savvy_finance_upgradeable()
        savvy_finance_proxy = deploy_transparent_upgradeable_proxy(
            proxy_admin, savvy_finance, web3.toWei(1000000, "ether")
        )
        savvy_finance_farm = deploy_savvy_finance_farm()
        savvy_finance_farm_proxy = deploy_transparent_upgradeable_proxy(
            proxy_admin, savvy_finance_farm
        )
    elif deploy == "farm":
        proxy_admin = ProxyAdmin[-1]
        # savvy_finance = SavvyFinanceUpgradeable[-1]
        savvy_finance_proxy = TransparentUpgradeableProxy[-2]
        savvy_finance_farm = deploy_savvy_finance_farm()
        savvy_finance_farm_proxy = deploy_transparent_upgradeable_proxy(
            proxy_admin, savvy_finance_farm
        )
    else:
        proxy_admin = ProxyAdmin[-1]
        # savvy_finance = SavvyFinanceUpgradeable[-1]
        savvy_finance_proxy = TransparentUpgradeableProxy[-2]
        # savvy_finance_farm = SavvyFinanceFarm[-1]
        savvy_finance_farm_proxy = TransparentUpgradeableProxy[-1]

    proxy_savvy_finance = Contract.from_abi(
        savvy_finance._name, savvy_finance_proxy.address, savvy_finance.abi
    )
    proxy_savvy_finance_farm = Contract.from_abi(
        savvy_finance_farm._name,
        savvy_finance_farm_proxy.address,
        savvy_finance_farm.abi,
    )
    return proxy_admin, proxy_savvy_finance, proxy_savvy_finance_farm


def main():
    # print_json(SavvyFinanceUpgradeable.get_verification_info())

    proxy_admin, proxy_savvy_finance, proxy_savvy_finance_farm = get_contracts("all")

    #####
    # print(proxy_admin.owner(), get_account().address)
    # print(proxy_admin.getProxyAdmin(savvy_finance_proxy), proxy_admin.address)
    # print(proxy_admin.getProxyAdmin(savvy_finance_farm_proxy), proxy_admin.address)
    # print(
    #     proxy_admin.getProxyImplementation(savvy_finance_proxy), savvy_finance.address
    # )
    # print(
    #     proxy_admin.getProxyImplementation(savvy_finance_farm_proxy),
    #     savvy_finance_farm.address,
    # )
    # print(savvy_finance_farm.developmentWallet())
    # print(proxy_savvy_finance_farm.developmentWallet())
    # print(savvy_finance_farm.toRole(get_tokens()["wbnb"]))
    # print(proxy_savvy_finance_farm.toRole(get_tokens()["wbnb"]))
    #####

    tokens = {"svf": proxy_savvy_finance.address} | get_tokens()
    set_token_types(proxy_savvy_finance_farm, ["DEFAULT", "LP"])
    add_tokens(proxy_savvy_finance_farm, tokens)
    activate_tokens(proxy_savvy_finance_farm, tokens)
    set_tokens_prices(proxy_savvy_finance_farm, tokens)
    enable_tokens_multi_reward(
        proxy_savvy_finance_farm,
        {
            "svf": proxy_savvy_finance.address,
            "wbnb": get_contract("wbnb_token").address,
        },
    )

    # add_tokens(proxy_savvy_finance_farm, {"svf": tokens["svf"]})
    # activate_tokens(proxy_savvy_finance_farm, {"svf": tokens["svf"]})
    # set_tokens_prices(proxy_savvy_finance_farm, {"svf": tokens["svf"]})
    #####
    deposit_token(proxy_savvy_finance_farm, proxy_savvy_finance, 20000)
    withdraw_token(proxy_savvy_finance_farm, proxy_savvy_finance, 10000)
    exclude_from_fees(proxy_savvy_finance_farm, get_account().address)
    stake_token(proxy_savvy_finance_farm, proxy_savvy_finance, 1000)
    unstake_token(proxy_savvy_finance_farm, proxy_savvy_finance, 500)
    stake_token(proxy_savvy_finance_farm, proxy_savvy_finance, 500)

    #####
    # print(
    #     proxy_savvy_finance_farm.calculateStakerStakingRewardValue(
    #         get_account().address, tokens["svf"]
    #     )
    # )
    # print(
    #     web3.fromWei(
    #         proxy_savvy_finance_farm.calculateStakerStakingRewardValue(
    #             get_account().address, tokens["svf"]
    #         ),
    #         "ether",
    #     )
    # )
    # proxy_savvy_finance_farm.issueStakingRewards({"from": get_account()}).wait(1)
    # proxy_savvy_finance_farm.issueStakingRewards({"from": get_account()}).wait(1)
    #####

    print_json(get_tokens_data(proxy_savvy_finance_farm))
    print_json(get_stakers_data(proxy_savvy_finance_farm))
    print_json(get_tokens_stakers_data(proxy_savvy_finance_farm))
    print(
        web3.fromWei(
            proxy_savvy_finance.balanceOf(proxy_savvy_finance_farm.address), "ether"
        )
    )
    print(web3.fromWei(proxy_savvy_finance.balanceOf(get_account().address), "ether"))
