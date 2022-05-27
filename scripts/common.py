from brownie import (
    # MockToken,
    MockLINKToken,
    MockOracle,
    MockV3Aggregator,
    VRFCoordinatorV2Mock,
    # Contract,
    network,
    accounts,
    config,
    web3,
    interface,
)
import json, requests

NON_FORKED_LOCAL_BLOCKCHAIN_ENVIRONMENTS = ["development", "ganache", "hardhat"]
FORKED_LOCAL_BLOCKCHAIN_ENVIRONMENTS = [
    "mainnet-fork",
    "bsc-main-fork",
]
LOCAL_BLOCKCHAIN_ENVIRONMENTS = (
    NON_FORKED_LOCAL_BLOCKCHAIN_ENVIRONMENTS + FORKED_LOCAL_BLOCKCHAIN_ENVIRONMENTS
)

contract_name_to_mock = {
    # "token": MockToken,
    "link_token": MockLINKToken,
    "oracle": MockOracle,
    "eth_usd_price_feed": MockV3Aggregator,
    "vrf_coordinator": VRFCoordinatorV2Mock,
}


def print_json(json_data):
    print(json.dumps(json_data, sort_keys=False, indent=4))


def get_account(index=0, id=None):
    if network.show_active() in LOCAL_BLOCKCHAIN_ENVIRONMENTS:
        return accounts[index]
    if id:
        return accounts.load(id)
    return accounts.add(config["wallets"]["development"]["private_key"])


def get_address(address_name):
    return config["addresses"][address_name]


def get_token_price(token_address, network_name=network.show_active()):
    response = requests.get(
        "https://api.pancakeswap.info/api/v2/tokens/{}".format(token_address)
    )
    return float(response.json()["data"]["price"])


def get_lp_token_price(lp_token_address, network_name=network.show_active()):
    lp_token_contract = interface.IPancakePair(lp_token_address)
    lp_token_supply = float(web3.fromWei(lp_token_contract.totalSupply(), "ether"))
    lp_token_pair_0_address = lp_token_contract.token0()
    lp_token_pair_1_address = lp_token_contract.token1()
    lp_token_pair_reserves = lp_token_contract.getReserves()
    lp_token_pair_0_reserve = float(web3.fromWei(lp_token_pair_reserves[0], "ether"))
    lp_token_pair_1_reserve = float(web3.fromWei(lp_token_pair_reserves[1], "ether"))
    lp_token_pair_0_price = get_token_price(lp_token_pair_0_address)
    lp_token_pair_1_price = get_token_price(lp_token_pair_1_address)
    lp_token_pair_0_value = lp_token_pair_0_reserve * lp_token_pair_0_price
    lp_token_pair_1_value = lp_token_pair_1_reserve * lp_token_pair_1_price
    lp_token_value = lp_token_pair_0_value + lp_token_pair_1_value
    lp_token_price = lp_token_value / lp_token_supply
    return lp_token_price


def get_contract_address(contract_name, network_name=network.show_active()):
    return config["networks"][network_name]["contracts"][contract_name]


def get_contract(contract_name):
    """
    If you want to use this function, go to the brownie config and add a new entry for
    the contract that you want to be able to 'get'. Then add an entry in the variable 'contract_to_mock'.
    You'll see examples like the 'link_token'.
        This script will then either:
            - Get a address from the config
            - Or deploy a mock to use for a network that doesn't have it
        Args:
            contract_name (string): This is the name that is referred to in the
            brownie config and 'contract_to_mock' variable.
        Returns:
            brownie.network.contract.ProjectContract: The most recently deployed
            Contract of the type specificed by the dictionary. This could be either
            a mock or the 'real' contract on a live network.
    """
    if network.show_active() in NON_FORKED_LOCAL_BLOCKCHAIN_ENVIRONMENTS:
        try:
            contract_mock = contract_name_to_mock[contract_name]
            if len(contract_mock) <= 0:
                deploy_contract_mocks()
            contract = contract_mock[-1]
        except KeyError:
            print(
                f"""
                {contract_name} contract mock not found for {network.show_active()} network.
                Add it to contract_name_to_mock in scripts/common.py
                """
            )
    else:
        try:
            contract_address = get_contract_address(contract_name)
            contract = interface.IERC20(contract_address)
            # contract = Contract.from_abi(
            #     contract_mock._name, contract_address, contract_mock.abi
            # )
        except KeyError:
            print(
                f"""
                {contract_name} contract address not found for {network.show_active()} network.
                Add it to config["networks"][{network.show_active()}]["contracts"] in brownie-config.yaml
                """
            )
    return contract


def deploy_contract_mocks(account=get_account()):
    """
    Use this script if you want to deploy contract mocks to a testnet.
    """
    print(f"Current active network is {network.show_active()}.")
    print("Deploying Contract Mocks...")
    # print("Deploying Mock Token...")
    # token = MockToken.deploy({"from": account})
    print("Deploying Mock LINK Token...")
    link_token = MockLINKToken.deploy({"from": account})
    print("Deploying Mock Oracle...")
    mock_oracle = MockOracle.deploy(link_token.address, {"from": account})
    print("Deploying Mock Price Feed...")
    price_feed = MockV3Aggregator.deploy(
        18, web3.toWei(3000, "ether"), {"from": account}
    )
    print("Deploying Mock VRFCoordinator...")
    vrf_coordinator = VRFCoordinatorV2Mock.deploy(
        web3.toWei(0.1, "ether"), web3.toWei(0.000000001, "ether"), {"from": account}
    )
    print("Contract Mocks Deployed!")


def fund_with_link(address, amount=web3.toWei(0.1, "ether"), account=get_account()):
    link_token = get_contract("link_token")
    ### Keep this line to show how it could be done without deploying a contract mock.
    # tx = interface.ILinkToken(link_token.address).transfer(
    #     address, amount, {"from": account}
    # )
    tx = link_token.transfer(address, amount, {"from": account})
    print("Funded {} with {} LINK.".format(address, web3.fromWei(amount, "ether")))
    return tx


def encode_function_data(*args, initializer=None):
    """Encodes the function call so we can work with an initializer.
    Args:
        initializer ([brownie.network.contract.ContractTx], optional):
        The initializer function we want to call. Example: `box.store`.
        Defaults to None.
        args (Any, optional):
        The arguments to pass to the initializer function
    Returns:
        [bytes]: Return the encoded bytes.
    """
    if not len(args):
        args = b""

    if initializer:
        return initializer.encode_input(*args)

    return b""


def upgrade(
    account,
    proxy,
    newimplementation_address,
    proxy_admin_contract=None,
    initializer=None,
    *args,
):
    transaction = None
    if proxy_admin_contract:
        if initializer:
            encoded_function_call = encode_function_data(initializer, *args)
            transaction = proxy_admin_contract.upgradeAndCall(
                proxy.address,
                newimplementation_address,
                encoded_function_call,
                {"from": account},
            )
        else:
            transaction = proxy_admin_contract.upgrade(
                proxy.address, newimplementation_address, {"from": account}
            )
    else:
        if initializer:
            encoded_function_call = encode_function_data(initializer, *args)
            transaction = proxy.upgradeToAndCall(
                newimplementation_address, encoded_function_call, {"from": account}
            )
        else:
            transaction = proxy.upgradeTo(newimplementation_address, {"from": account})
    return transaction
