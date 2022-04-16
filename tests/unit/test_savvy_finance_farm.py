from brownie import network, exceptions, web3
from scripts.common import LOCAL_BLOCKCHAIN_ENVIRONMENTS, get_account
from scripts.savvy_finance_farm import (
    deploy_savvy_finance,
    deploy_savvy_finance_farm,
    get_tokens,
    add_allowed_tokens,
    remove_allowed_tokens,
)
import pytest


def test_add_allowed_tokens():
    if network.show_active() not in LOCAL_BLOCKCHAIN_ENVIRONMENTS:
        pytest.skip()
    account = get_account()
    savvy_finance_farm = deploy_savvy_finance_farm(account)
    tokens = get_tokens()
    add_allowed_tokens(savvy_finance_farm, tokens)
    assert savvy_finance_farm.allowedTokens(0) == tokens[0]
    assert savvy_finance_farm.allowedTokens(1) == tokens[1]
    assert savvy_finance_farm.allowedTokens(2) == tokens[2]


def test_remove_allowed_tokens():
    if network.show_active() not in LOCAL_BLOCKCHAIN_ENVIRONMENTS:
        pytest.skip()
    account = get_account()
    savvy_finance_farm = deploy_savvy_finance_farm(account)
    tokens = get_tokens()
    add_allowed_tokens(savvy_finance_farm, tokens)
    remove_allowed_tokens(savvy_finance_farm, [tokens[0]])
    assert savvy_finance_farm.allowedTokens(0) == tokens[2]
    assert savvy_finance_farm.allowedTokens(1) == tokens[1]
    with pytest.raises(exceptions.VirtualMachineError):
        savvy_finance_farm.allowedTokens(2)


def test_token_is_allowed():
    if network.show_active() not in LOCAL_BLOCKCHAIN_ENVIRONMENTS:
        pytest.skip()
    account = get_account()
    savvy_finance_farm = deploy_savvy_finance_farm(account)
    tokens = get_tokens()
    add_allowed_tokens(savvy_finance_farm, tokens)
    remove_allowed_tokens(savvy_finance_farm, [tokens[0]])
    assert savvy_finance_farm.tokenIsAllowed(tokens[0]) == False
    assert savvy_finance_farm.tokenIsAllowed(tokens[1]) == True
    assert savvy_finance_farm.tokenIsAllowed(tokens[2]) == True


def test_stake_token():
    if network.show_active() not in LOCAL_BLOCKCHAIN_ENVIRONMENTS:
        pytest.skip()
    account = get_account()
    savvy_finance = deploy_savvy_finance(account)
    savvy_finance_farm = deploy_savvy_finance_farm(account)
    add_allowed_tokens(savvy_finance_farm, [savvy_finance.address])
    stake_amount_1 = web3.toWei(10000, "ether")
    savvy_finance.approve(savvy_finance_farm.address, stake_amount_1).wait(1)
    savvy_finance_farm.stakeToken(savvy_finance.address, stake_amount_1).wait(1)
    assert savvy_finance.balanceOf(savvy_finance_farm.address) == stake_amount_1
    assert (
        savvy_finance_farm.stakingData(savvy_finance.address, account.address)
        == stake_amount_1
    )
    assert savvy_finance_farm.stakers(0) == account.address
    assert savvy_finance_farm.stakersToUniqueTokensStaked(account.address) == 1
    return account, savvy_finance, savvy_finance_farm, stake_amount_1


def test_stake_token_again():
    account, savvy_finance, savvy_finance_farm, stake_amount_1 = test_stake_token()
    stake_amount_2 = web3.toWei(10000, "ether")
    savvy_finance.approve(savvy_finance_farm.address, stake_amount_2).wait(1)
    savvy_finance_farm.stakeToken(savvy_finance.address, stake_amount_2).wait(1)
    total_stake_amount = stake_amount_1 + stake_amount_2
    assert savvy_finance.balanceOf(savvy_finance_farm.address) == total_stake_amount
    assert (
        savvy_finance_farm.stakingData(savvy_finance.address, account.address)
        == total_stake_amount
    )
    assert savvy_finance_farm.stakers(0) == account.address
    assert savvy_finance_farm.stakersToUniqueTokensStaked(account.address) == 1


def test_stake_token_another():
    account, savvy_finance, savvy_finance_farm, stake_amount_1 = test_stake_token()
    savvy_finance_2 = deploy_savvy_finance(account)
    add_allowed_tokens(savvy_finance_farm, [savvy_finance_2.address])
    stake_amount = web3.toWei(10000, "ether")
    savvy_finance_2.approve(savvy_finance_farm.address, stake_amount).wait(1)
    savvy_finance_farm.stakeToken(savvy_finance_2.address, stake_amount).wait(1)
    assert savvy_finance_2.balanceOf(savvy_finance_farm.address) == stake_amount
    assert (
        savvy_finance_farm.stakingData(savvy_finance_2.address, account.address)
        == stake_amount
    )
    assert savvy_finance_farm.stakers(0) == account.address
    assert savvy_finance_farm.stakersToUniqueTokensStaked(account.address) == 2
    return account, savvy_finance_2, savvy_finance_farm, stake_amount


def test_unstake_token():
    account, savvy_finance, savvy_finance_farm, stake_amount_1 = test_stake_token()
    unstake_amount_1 = stake_amount_1 / 2
    savvy_finance_farm.unstakeToken(savvy_finance.address, unstake_amount_1).wait(1)
    assert savvy_finance.balanceOf(savvy_finance_farm.address) == unstake_amount_1
    assert (
        savvy_finance_farm.stakingData(savvy_finance.address, account.address)
        == unstake_amount_1
    )
    assert savvy_finance_farm.stakers(0) == account.address
    assert savvy_finance_farm.stakersToUniqueTokensStaked(account.address) == 1
    return account, savvy_finance, savvy_finance_farm, unstake_amount_1


def test_unstake_token_again():
    account, savvy_finance, savvy_finance_farm, unstake_amount_1 = test_unstake_token()
    savvy_finance_farm.unstakeToken(savvy_finance.address, unstake_amount_1).wait(1)
    assert savvy_finance.balanceOf(savvy_finance_farm.address) == 0
    assert savvy_finance_farm.stakingData(savvy_finance.address, account.address) == 0
    with pytest.raises(exceptions.VirtualMachineError):
        savvy_finance_farm.stakers(0)
    assert savvy_finance_farm.stakersToUniqueTokensStaked(account.address) == 0


def test_unstake_token_another():
    (
        account,
        savvy_finance_2,
        savvy_finance_farm,
        stake_amount,
    ) = test_stake_token_another()
    savvy_finance_farm.unstakeToken(savvy_finance_2.address, stake_amount).wait(1)
    assert savvy_finance_2.balanceOf(savvy_finance_farm.address) == 0
    assert savvy_finance_farm.stakingData(savvy_finance_2.address, account.address) == 0
    assert savvy_finance_farm.stakers(0) == account.address
    assert savvy_finance_farm.stakersToUniqueTokensStaked(account.address) == 1
