from scripts.helpful_scripts import (
    get_account,
    get_contract,
    config,
    network,
    fund_with_link,
)
from brownie import Lottery
import time


def deploy_lottery():
    account = get_account()
    # Here, in deploy() function, all the parameters that have been used in the constructor of Lottery contract should be given
    lottery = Lottery.deploy(
        get_contract("eth_usd_price_feed").address,  # Price_feed
        get_contract("vrf_coordinator").address,  # vrfCoordinator
        get_contract("link_token").address,  # link
        config["networks"][network.show_active()]["fee"],  # fee
        config["networks"][network.show_active()]["keyhash"],  # keyhash
        {"from": account},
        # This is to give permission to publish. <.get("verify", False) is done so that if verify is not given, default value will be given as false.
        publish_source=config["networks"][network.show_active()].get("verify", False),
    )
    print("Lottery Deployed!")


# This function is a function in python that accesses a contract<Lottery> and its function <startLottery>from solidity
def start_lottery():
    account = get_account()
    lottery = Lottery[-1]
    tx = lottery.startLottery({"from": account})
    tx.wait(1)
    print("The lottery is started!")


def enter_lottery():
    account = get_account()
    lottery = Lottery[-1]
    # This is the value to be given so that you can enter the lottery. +1 gwei is done as occassionally, there might be certain error in the execution. This is not compulsion though
    value = lottery.getEntranceFee() + 100000000
    tx = lottery.enter({"from": account, "value": value})
    tx.wait(1)
    print("You have entered the lottery!")


def end_lottery():
    account = get_account()
    lottery = Lottery[-1]
    # Note that the endLottery() function of Lottery.sol calls the RequestRandomness() function. So, to call this function, some fee/link token is required.
    # So, first we need to fund our contract <The function is created in helpful_scripts
    tx = fund_with_link(lottery.address)
    tx.wait(1)
    # and only then end the lottery
    ending_transaction = lottery.endLottery({"from": account})
    ending_transaction.wait(1)
    # Remember that when requesting for randomness in lottery.sol, we first had to request than the chainlink would respond with the data. So, for this some extra seconds would be required so that time.sleep(60) is done.
    time.sleep(60)
    print(f"{lottery.recentWinner()} is the new winner!")


def main():
    deploy_lottery()
    start_lottery()
    enter_lottery()
    end_lottery()
    # Note that end_lottery won't return the winner if the contract is deployed form ganache. You need to use a test net. This is because ganache do not have a chainlink associated with it for returning a random address
