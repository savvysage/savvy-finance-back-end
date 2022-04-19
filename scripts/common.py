from brownie import (
    MockWETH,
    MockDAI,
    LinkToken,
    MockOracle,
    MockV3Aggregator,
    VRFCoordinatorV2Mock,
    Contract,
    network,
    accounts,
    config,
    web3,
)

NON_FORKED_LOCAL_BLOCKCHAIN_ENVIRONMENTS = ["hardhat", "development", "ganache"]
FORKED_LOCAL_BLOCKCHAIN_ENVIRONMENTS = [
    "mainnet-fork",
    "binance-fork",
    "matic-fork",
]
LOCAL_BLOCKCHAIN_ENVIRONMENTS = (
    NON_FORKED_LOCAL_BLOCKCHAIN_ENVIRONMENTS + FORKED_LOCAL_BLOCKCHAIN_ENVIRONMENTS
)

contract_name_to_mock = {
    "weth_token": MockWETH,
    "dai_token": MockDAI,
    "link_token": LinkToken,
    "oracle": MockOracle,
    "eth_usd_price_feed": MockV3Aggregator,
    "vrf_coordinator": VRFCoordinatorV2Mock,
}


def get_account(index=0, id=None):
    if network.show_active() in LOCAL_BLOCKCHAIN_ENVIRONMENTS:
        return accounts[index]
    if id:
        return accounts.load(id)
    return accounts.add(config["wallets"]["development"]["private_key"])


def get_address(address_name):
    return config["addresses"][address_name]


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
    contract_mock = contract_name_to_mock[contract_name]
    if network.show_active() in NON_FORKED_LOCAL_BLOCKCHAIN_ENVIRONMENTS:
        if len(contract_mock) <= 0:
            deploy_contract_mocks()
        contract = contract_mock[-1]
    else:
        try:
            contract_address = config["networks"][network.show_active()]["contracts"][
                contract_name
            ]
            contract = Contract.from_abi(
                contract_mock._name, contract_address, contract_mock.abi
            )
        except KeyError:
            print(
                f"{contract_name} contract address not found for {network.show_active()} network."
            )
            print(
                f'Add it to config["networks"][{network.show_active()}]["contracts"] in brownie-config.yaml'
            )
    return contract


def deploy_contract_mocks():
    """
    Use this script if you want to deploy contract mocks to a testnet.
    """
    print(f"Current active network is {network.show_active()}.")
    print("Deploying Contract Mocks...")
    account = get_account()
    print("Deploying Mock WETH...")
    mock_weth = MockWETH.deploy({"from": account})
    print("Deploying Mock DAI...")
    mock_dai = MockDAI.deploy({"from": account})
    print("Deploying Mock Link Token...")
    link_token = LinkToken.deploy({"from": account})
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
