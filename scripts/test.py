tokens_dict = {
    "wbnb": "get_contract('wbnb_token').address",
    "busd": "get_contract('busd_token').address",
    "wbnb_busd": "get_contract('wbnb_busd_lp_token').address",
}

tokens_arr = [
    "get_contract('wbnb_token').address",
    "get_contract('busd_token').address",
    "get_contract('wbnb_busd_lp_token').address",
]


def main():
    print(list(tokens_dict.values()))
    print(type(tokens_dict))
    print(isinstance(tokens_dict, dict), "\n")
    print(tokens_arr)
    print(type(tokens_arr))
    print(isinstance(tokens_arr, list), "\n")
