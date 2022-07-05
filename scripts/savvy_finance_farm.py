from brownie import (
    ProxyAdmin,
    TransparentUpgradeableProxy,
    SavvyFinance,
    SavvyFinanceUpgradeable,
    SavvyFinanceFarmLibrary,
    SavvyFinanceFarm,
    Contract,
    network,
    config,
    web3,
)
from scripts.common import (
    print_json,
    copy_folder,
    to_wei,
    from_wei,
    get_account,
    get_address,
    get_token_price,
    get_lp_token_price,
    get_contract_address,
    get_contract,
    deploy_proxy_admin,
    deploy_transparent_upgradeable_proxy,
    upgrade_transparent_upgradeable_proxy,
)
import shutil, yaml, json


def get_tokens():
    return {
        "wbnb": get_contract("wbnb_token").address,
        "busd": get_contract("busd_token").address,
        "wbnb_busd": get_contract("wbnb_busd_lp_token").address,
    }


def deploy_savvy_finance(account=get_account()):
    return SavvyFinance.deploy(
        web3.toWei(1000000, "ether"),
        {"from": account},
        publish_source=config["networks"][network.show_active()].get("verify", False),
    )


def deploy_savvy_finance_upgradeable(account=get_account()):
    return SavvyFinanceUpgradeable.deploy(
        {"from": account},
        publish_source=config["networks"][network.show_active()].get("verify", False),
    )


def deploy_savvy_finance_farm_library(account=get_account()):
    return SavvyFinanceFarmLibrary.deploy(
        {"from": account},
        publish_source=config["networks"][network.show_active()].get("verify", False),
    )


def deploy_savvy_finance_farm(account=get_account()):
    return SavvyFinanceFarm.deploy(
        {"from": account},
        publish_source=config["networks"][network.show_active()].get("verify", False),
    )


def erc20_token_transfer(token_contract, to, amount, account=get_account()):
    amount2 = to_wei(amount)
    token_contract.transfer(to, amount2, {"from": account}).wait(1)
    print(
        "Transferred "
        + str(amount)
        + " "
        + token_contract.symbol()
        + " to "
        + to
        + ".",
        "\n\n",
    )


def get_tokens_data(contract, tokens=None, account=get_account()):
    if not tokens:
        tokens = list(contract.getTokens())
    else:
        tokens = list(tokens.values())

    tokens_data = []
    for token in tokens:
        token_data = contract.getTokenData(token)
        token_data_dict = {
            "address": token,
            "isActive": token_data[0],
            "isVerified": token_data[1],
            "hasMultiTokenRewards": token_data[2],
            "name": token_data[3],
            "category": token_data[4],
            "price": float(from_wei(token_data[5])),
            "rewardBalance": float(from_wei(token_data[6])),
            "stakingBalance": float(from_wei(token_data[7])),
            "stakingApr": float(from_wei(token_data[8])),
            "rewardToken": token_data[9],
            "admin": token_data[10],
            "devDepositFee": float(from_wei(token_data[11][0])),
            "devWithdrawFee": float(from_wei(token_data[11][1])),
            "devStakeFee": float(from_wei(token_data[11][2])),
            "devUnstakeFee": float(from_wei(token_data[11][3])),
            "adminStakeFee": float(from_wei(token_data[11][4])),
            "adminUnstakeFee": float(from_wei(token_data[11][5])),
            "timestampAdded": token_data[12],
            "timestampLastUpdated": token_data[13],
        }
        tokens_data.append(token_data_dict)
    return tokens_data


def get_stakers_data(contract, stakers=None, account=get_account()):
    if not stakers:
        stakers = list(contract.getStakers())

    stakers_data = []
    for staker in stakers:
        staker_data = contract.getStakerData(staker)
        staker_data_dict = {
            "address": staker,
            "isActive": staker_data[0],
            "uniqueTokensStaked": staker_data[1],
            "timestampAdded": staker_data[2],
            "timestampLastUpdated": staker_data[3],
        }
        stakers_data.append(staker_data_dict)
    return stakers_data


def get_tokens_stakers_data(contract, tokens=None, stakers=None, account=get_account()):
    if not tokens:
        tokens = list(contract.getTokens())
    else:
        tokens = list(tokens.values())
    if not stakers:
        stakers = list(contract.getStakers())

    tokens_stakers_data = []
    for token in tokens:
        token_stakers_data = {}
        for staker in stakers:
            token_staker_data = contract.getTokenStakerData(token, staker)
            staking_rewards = []
            for staking_reward in token_staker_data[3]:
                staking_reward_dict = {
                    "id": staking_reward[0],
                    "staker": staking_reward[1],
                    "rewardToken": staking_reward[2],
                    "rewardTokenPrice": float(web3.fromWei(staking_reward[3], "ether")),
                    "rewardTokenAmount": float(
                        web3.fromWei(staking_reward[4], "ether")
                    ),
                    "stakedToken": staking_reward[5],
                    "stakedTokenPrice": float(web3.fromWei(staking_reward[6], "ether")),
                    "stakedTokenAmount": float(
                        web3.fromWei(staking_reward[7], "ether")
                    ),
                    "stakingApr": float(web3.fromWei(staking_reward[8], "ether")),
                    "stakingDurationInSeconds": float(
                        web3.fromWei(staking_reward[9], "ether")
                    ),
                    "triggeredBy": list(staking_reward[10]),
                    "timestampAdded": staking_reward[11],
                    "timestampLastUpdated": staking_reward[12],
                }
                staking_rewards.append(staking_reward_dict)
            token_staker_data_dict = {
                "rewardBalance": float(web3.fromWei(token_staker_data[0], "ether")),
                "stakingBalance": float(web3.fromWei(token_staker_data[1], "ether")),
                "stakingRewardToken": token_staker_data[2],
                "stakingRewards": staking_rewards,
                "timestampLastRewarded": token_staker_data[4],
                "timestampAdded": token_staker_data[5],
                "timestampLastUpdated": token_staker_data[6],
            }
            token_stakers_data[staker] = token_staker_data_dict
        tokens_stakers_data.append({token: token_stakers_data})
    return tokens_stakers_data


def exclude_from_fees(contract, address, account=get_account()):
    contract.excludeFromFees(address, {"from": account}).wait(1)


def include_in_fees(contract, address, account=get_account()):
    contract.includeInFees(address, {"from": account}).wait(1)


def set_token_categories(contract, categories, account=get_account()):
    for index, category in enumerate(categories):
        contract.configTokenCategory(index, category, {"from": account}).wait(1)


def add_tokens(contract, tokens=get_tokens(), account=get_account()):
    for token_name in tokens:
        token = tokens[token_name]
        token_name_2 = token_name.replace("_", "-").upper()
        token_category = 0 if ("_" not in token_name) else 1
        token_staking_apr = to_wei(100)
        token_admin_stake_fee = to_wei(1)
        token_admin_unstake_fee = to_wei(1)
        token_reward_token = token
        contract.addToken(
            token,
            token_name_2,
            token_category,
            token_staking_apr,
            token_admin_stake_fee,
            token_admin_unstake_fee,
            token_reward_token,
            {"from": account},
        ).wait(1)
        print("Added " + token_name + " token.", "\n\n")


def exclude_from_token_admin_fees(
    contract, token_contract, address, account=get_account()
):
    contract.excludeFromTokenAdminFees(
        token_contract.address, address, {"from": account}
    ).wait(1)


def include_in_token_admin_fees(
    contract, token_contract, address, account=get_account()
):
    contract.includeInTokenAdminFees(
        token_contract.address, address, {"from": account}
    ).wait(1)


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


def verify_tokens(contract, tokens=get_tokens(), account=get_account()):
    for token_name in tokens:
        token = tokens[token_name]
        contract.verifyToken(token, {"from": account}).wait(1)
        print("Verified " + token_name + " token.", "\n\n")


def unverify_tokens(contract, tokens=get_tokens(), account=get_account()):
    for token_name in tokens:
        token = tokens[token_name]
        contract.unverifyToken(token, {"from": account}).wait(1)
        print("Unverified " + token_name + " token.", "\n\n")


def enable_tokens_multi_token_rewards(
    contract, tokens=get_tokens(), account=get_account()
):
    for token_name in tokens:
        token = tokens[token_name]
        contract.enableTokenMultiTokenRewards(token, {"from": account}).wait(1)
        print("Enabled " + token_name + " token multi token rewards.", "\n\n")


def disable_tokens_multi_token_rewards(
    contract, tokens=get_tokens(), account=get_account()
):
    for token_name in tokens:
        token = tokens[token_name]
        contract.disableTokenMultiTokenRewards(token, {"from": account}).wait(1)
        print("Disabled " + token_name + " token multi token rewards.", "\n\n")


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


def set_token_reward_token(
    contract, token_contract, reward_token_contract, account=get_account()
):
    contract.setTokenRewardToken(
        token_contract.address, reward_token_contract.address, {"from": account}
    ).wait(1)
    print(
        token_contract.symbol()
        + " token reward token set to "
        + reward_token_contract.symbol()
        + ".",
        "\n\n",
    )


def deposit_token(contract, token_contract, amount, account=get_account()):
    amount2 = web3.toWei(amount, "ether")
    token_contract.approve(contract.address, amount2, {"from": account}).wait(1)
    contract.depositToken(token_contract.address, amount2, {"from": account}).wait(1)
    print("Deposited " + str(amount) + " " + token_contract.symbol() + ".", "\n\n")


def withdraw_token(contract, token_contract, amount, account=get_account()):
    amount2 = web3.toWei(amount, "ether")
    contract.withdrawToken(token_contract.address, amount2, {"from": account}).wait(1)
    print("Withdrew " + str(amount) + " " + token_contract.symbol() + ".", "\n\n")


def set_staking_reward_token(
    contract, token_contract, reward_token_contract, account=get_account()
):
    contract.setStakingRewardToken(
        token_contract.address, reward_token_contract.address, {"from": account}
    ).wait(1)
    print(
        token_contract.symbol()
        + " staking reward token set to "
        + reward_token_contract.symbol()
        + ".",
        "\n\n",
    )


def stake_token(contract, token_contract, amount, account=get_account()):
    amount2 = web3.toWei(amount, "ether")
    token_contract.approve(contract.address, amount2, {"from": account}).wait(1)
    contract.stakeToken(token_contract.address, amount2, {"from": account}).wait(1)
    print("Staked " + str(amount) + " " + token_contract.symbol() + ".", "\n\n")


def unstake_token(contract, token_contract, amount, account=get_account()):
    amount2 = web3.toWei(amount, "ether")
    contract.unstakeToken(token_contract.address, amount2, {"from": account}).wait(1)
    print("Unstaked " + str(amount) + " " + token_contract.symbol() + ".", "\n\n")


def claim_staking_reward(contract, token_contract, account=get_account()):
    contract.claimStakingReward(token_contract.address, {"from": account}).wait(1)
    print(
        "Claimed " + token_contract.symbol() + " staking reward.",
        "\n\n",
    )


def withdraw_staking_reward(
    contract, reward_token_contract, amount, account=get_account()
):
    amount2 = web3.toWei(amount, "ether")
    contract.withdrawRewardToken(
        reward_token_contract.address, amount2, {"from": account}
    ).wait(1)
    print(
        "Withdrew " + str(amount) + " " + reward_token_contract.symbol() + " reward.",
        "\n\n",
    )


def generate_front_end_tokens_data(contract):
    tokens_data = get_tokens_data(contract)
    for token_data in tokens_data:
        category = token_data["category"]
        name = token_data["name"].lower()
        token_data["icon"] = (
            ["/savvy-finance/icons/{}.png".format(name)]
            if category == 0
            else [
                "/savvy-finance/icons/{}.png".format(name.split("-")[0]),
                "/savvy-finance/icons/{}.png".format(name.split("-")[1]),
            ]
        )
        token_data["stakerData"] = {
            "walletBalance": 0,
            "rewardBalance": 0,
            "stakingBalance": 0,
            "stakingRewardToken": get_address("zero"),
            "stakingRewards": [
                # {
                #     "id": 0,
                #     "staker": get_address("zero"),
                #     "rewardToken": get_address("zero"),
                #     "rewardTokenPrice": 0,
                #     "rewardTokenAmount": 0,
                #     "stakedToken": get_address("zero"),
                #     "stakedTokenPrice": 0,
                #     "stakedTokenAmount": 0,
                #     "stakingApr": 0,
                #     "stakingDurationInSeconds": 0,
                #     "triggeredBy": ["", ""],
                #     "timestampAdded": 0,
                #     "timestampLastUpdated": 0,
                # }
            ],
            "timestampLastRewarded": 0,
            "timestampAdded": 0,
            "timestampLastUpdated": 0,
        }
    with open("./tokens.json", "w") as front_end_tokens_data:
        json.dump(tokens_data, front_end_tokens_data)


def update_front_end():
    copy_folder("./build", "../front_end/src/back_end_build")
    with open("./brownie-config.yaml", "r") as brownie_config:
        config_dict = yaml.load(brownie_config, Loader=yaml.FullLoader)
        with open(
            "../front_end/src/brownie-config.json", "w"
        ) as front_end_brownie_config:
            json.dump(config_dict, front_end_brownie_config)
    shutil.copyfile("./tokens.json", "../front_end/src/tokens.json")
    print("Front end updated!")


def upgrade_savvy_finance_farm():
    proxy_admin = ProxyAdmin[-1]
    savvy_finance_farm_proxy = TransparentUpgradeableProxy[-1]
    savvy_finance_farm_library = deploy_savvy_finance_farm_library()
    savvy_finance_farm = deploy_savvy_finance_farm()
    upgrade_transparent_upgradeable_proxy(
        proxy_admin, savvy_finance_farm_proxy, savvy_finance_farm
    )
    proxy_savvy_finance_farm = Contract.from_abi(
        savvy_finance_farm._name,
        savvy_finance_farm_proxy.address,
        savvy_finance_farm.abi,
    )
    return proxy_savvy_finance_farm


def get_contracts(deploy=None):
    if deploy == "all":
        proxy_admin = deploy_proxy_admin()
        savvy_finance = deploy_savvy_finance_upgradeable()
        savvy_finance_proxy = deploy_transparent_upgradeable_proxy(
            proxy_admin, savvy_finance, web3.toWei(1000000, "ether")
        )
        savvy_finance_farm_library = deploy_savvy_finance_farm_library()
        savvy_finance_farm = deploy_savvy_finance_farm()
        savvy_finance_farm_proxy = deploy_transparent_upgradeable_proxy(
            proxy_admin, savvy_finance_farm
        )
    elif deploy == "farm":
        proxy_admin = ProxyAdmin[-1]
        savvy_finance = SavvyFinanceUpgradeable[-1]
        savvy_finance_proxy = TransparentUpgradeableProxy[-2]
        savvy_finance_farm_library = deploy_savvy_finance_farm_library()
        savvy_finance_farm = deploy_savvy_finance_farm()
        savvy_finance_farm_proxy = deploy_transparent_upgradeable_proxy(
            proxy_admin, savvy_finance_farm
        )
    else:
        proxy_admin = ProxyAdmin[-1]
        savvy_finance = SavvyFinanceUpgradeable[-1]
        savvy_finance_proxy = TransparentUpgradeableProxy[-2]
        savvy_finance_farm_library = SavvyFinanceFarmLibrary[-1]
        savvy_finance_farm = SavvyFinanceFarm[-1]
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
    # print_json(SavvyFinanceFarm.get_verification_info())
    # contract = SavvyFinanceFarm.at("0xBF892C932C1eE21e7530Bde2a627a48db7Ebafd1")
    # SavvyFinanceFarm.publish_source(contract)

    proxy_admin, proxy_savvy_finance, proxy_savvy_finance_farm = get_contracts("all")
    # proxy_savvy_finance_farm = upgrade_savvy_finance_farm()

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
    # print(savvy_finance_farm.configData()[0])
    # print(proxy_savvy_finance_farm.configData()[0])
    # print(savvy_finance_farm.toRole(get_tokens()["wbnb"]))
    # print(proxy_savvy_finance_farm.toRole(get_tokens()["wbnb"]))
    #####

    account1 = get_account(1)
    account2 = get_account(2)
    # erc20_token_transfer(proxy_savvy_finance, account1.address, 10000)
    # erc20_token_transfer(proxy_savvy_finance, account2.address, 10000)

    tokens = {"svf": proxy_savvy_finance.address} | get_tokens()
    tokensx = {"svf": tokens["svf"], "wbnb_busd": tokens["wbnb_busd"]}

    #####
    # set_token_categories(proxy_savvy_finance_farm, ["DEFAULT", "LP"])
    # add_tokens(proxy_savvy_finance_farm, tokens, account1)
    # set_token_reward_token(
    #     proxy_savvy_finance_farm,
    #     get_contract("wbnb_busd_lp_token"),
    #     proxy_savvy_finance,
    #     account1,
    # )
    # activate_tokens(proxy_savvy_finance_farm, tokens)
    # set_tokens_prices(proxy_savvy_finance_farm, tokens)
    # verify_tokens(proxy_savvy_finance_farm, tokensx)
    # enable_tokens_multi_token_rewards(proxy_savvy_finance_farm, tokensx)
    # #####
    # exclude_from_fees(proxy_savvy_finance_farm, account1)
    # deposit_token(proxy_savvy_finance_farm, proxy_savvy_finance, 2000, account1)
    # withdraw_token(proxy_savvy_finance_farm, proxy_savvy_finance, 1000, account1)
    # #####
    # exclude_from_fees(proxy_savvy_finance_farm, account2)
    # exclude_from_token_admin_fees(
    #     proxy_savvy_finance_farm,
    #     proxy_savvy_finance,
    #     account2,
    #     account1,
    # )
    # stake_token(proxy_savvy_finance_farm, proxy_savvy_finance, 1000, account2)
    # claim_staking_reward(proxy_savvy_finance_farm, proxy_savvy_finance, account2)
    # stake_token(proxy_savvy_finance_farm, proxy_savvy_finance, 1000, account2)
    # unstake_token(proxy_savvy_finance_farm, proxy_savvy_finance, 500, account2)
    # unstake_token(proxy_savvy_finance_farm, proxy_savvy_finance, 500, account2)
    # withdraw_staking_reward(proxy_savvy_finance_farm, proxy_savvy_finance, 2, account2)
    #####

    #####
    # staking_reward_value = proxy_savvy_finance_farm._calculateStakingReward(
    #     tokens["svf"], get_account().address
    # )
    # print(staking_reward_value, from_wei(staking_reward_value))
    # print(
    #     proxy_savvy_finance_farm._issueStakingReward(
    #         proxy_savvy_finance.address,
    #         get_account().address,
    #         ["", ""],
    #         {"from": get_account()},
    #     )
    # )
    # proxy_savvy_finance_farm.issueStakingRewards({"from": get_account()}).wait(1)
    #####

    print_json(get_tokens_data(proxy_savvy_finance_farm))
    print_json(get_stakers_data(proxy_savvy_finance_farm))
    print_json(get_tokens_stakers_data(proxy_savvy_finance_farm))
    print(from_wei(proxy_savvy_finance.balanceOf(proxy_savvy_finance_farm.address)))
    print(from_wei(proxy_savvy_finance.balanceOf(account1.address)))
    print(from_wei(proxy_savvy_finance.balanceOf(account2.address)))
    print(from_wei(proxy_savvy_finance.balanceOf(get_account().address)))

    print(
        from_wei(
            SavvyFinanceFarmLibrary[-1].getTokenPrice(
                "0xbdd2e3fdb879aa42748e9d47b7359323f226ba22"
            )
        )
    )

    #####
    # generate_front_end_tokens_data(proxy_savvy_finance_farm)
    #####
