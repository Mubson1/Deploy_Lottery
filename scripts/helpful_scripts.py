from brownie import (
    accounts,
    network,
    config,
    MockV3Aggregator,
    Contract,
    VRFCoordinatorMock,
    LinkToken,
)

FORKED_LOCAL_ENVIRONMENT = ["mainnet-fork", "mainnet-fork-dev"]
LOCAL_BLOCKCHAIN_ENVIRONMENTS = ["development", "ganache-local"]

DECIMAL = 8
STARTING_PRICE = 2000000000000

# There are various accounts that may already exist. Eg. type brownie accounts list.
# So, if we want to get account that already existed, that's okay just give index <used here: accounts[]> or id <used here: # accounts.load("id")>.
def get_account(index=None, id=None):
    # Revision: Ways of creating account are:
    # accounts[0]
    # accounts.add("env")
    # accounts.load("id")
    if index:
        return accounts[index]
    if id:
        return accounts.load(id)

    if (
        network.show_active() in LOCAL_BLOCKCHAIN_ENVIRONMENTS
        or network.show_active() in FORKED_LOCAL_ENVIRONMENT
    ):
        return accounts[0]

    return accounts.add(config["wallets"]["from_key"])


# We are mapping the contract to mock
contract_to_mock = {
    "eth_usd_price_feed": MockV3Aggregator,
    "vrf_coordinator": VRFCoordinatorMock,
    "link_token": LinkToken,
}

# Here, get_contract receives certain parameter like "eth_usd_price_feed" which will give an address from .yaml. Now, we need to know the type of that contract i.e. if it is of MockV3Aggregator, VRFCoordinatorMock or LinkToken. So, a contract_mock is made above
def get_contract(contract_name):
    """
    This function will grab the contract address from the brownie config
    if defined, otherwise, it will deploy a mock version of that contract,
    and return that mock contract.

        Args:
            contract_name (string)
        Returns:
            brownie.network.contract.ProjectContract <i.e., The most recently
            version of this contract.>
    """
    contract_type = contract_to_mock[contract_name]
    # This is if the contract is deployed using development network
    if network.show_active() in LOCAL_BLOCKCHAIN_ENVIRONMENTS:
        # If the mock is not deployed, mock will be deployed using the following if condition
        if len(contract_type) <= 0:
            deploy_mocks()
        # Once, the mock is deployed, we wouldn't know it's contract. So, to get teh contract following is done.
        # This is same as doing: MockV3Aggregator[-1] <i.s., getting what is the recent deployement of the mock contract.>
        contract = contract_type[-1]
    # Now, if we deploy a contract using test networks, then , we have to get its contract address. Remember that it was easy to get an address of mock as above because we have imported AggregatorV3Interface. But in case of test networks we are have to code the entire thing to get the deployed contract's address
    else:
        contract_address = config["networks"][network.show_active()][contract_name]
        # So, to get the contract's address we need two things: Address and ABI. Address has been acbhievd from above and abi has already been achieved through contract_type
        # Here, a contract is created using the abi and Contract is the class that has been imported
        contract = Contract.from_abi(
            contract_type._name, contract_address, contract_type.abi
        )  # In the above, ._name gives the name and .abi gives the abi. These two are predefined attributes
    return contract


# A function to deploy the mock
DECIMALS = 8
INITIAL_VALUE = 200000000000


def deploy_mocks(decimals=DECIMALS, initial_value=INITIAL_VALUE):
    account = get_account()
    # Deploying MockV3Aggregator
    MockV3Aggregator.deploy(decimals, initial_value, {"from": account})
    # Deploying LinkToken mock which has no constructor. We are definig a variable for this becaue this token link is is needed as the constructor of the VRFCoordinator has this parameter
    link_token = LinkToken.deploy({"from": account})
    # Deploying VRFCoordinator mock with link_token as a paramater
    VRFCoordinatorMock.deploy(link_token, {"from": account})
    print("Deployed!")


# This function is used for the end_lottery() function in deploy_lottery
def fund_with_link(
    contract_address,  # The address of the contract
    account=None,  # Account can be given by the funder or else it becomes none by default.
    link_token=None,  # The token to be given can be set by funder or else it becomes none by default
    amount=100000000000000000,  # 0.1Link
):
    # Here, account varible is created which stores the value of account. If the account given by the sender exists, use that account else, call get_account() function
    account = account if account else get_account()
    # link_token varible is created which stores the value of link_token. If funder provides the link_token, use that account else, call the get_contract("link_token")
    link_token = link_token if link_token else get_contract("link_token")
    tx = link_token.transfer(contract_address, amount, {"from": account})
    tx.wait(1)
    print("Fund contract!")
    return tx
