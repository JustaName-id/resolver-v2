// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {Script, console2} from "forge-std/Script.sol";

abstract contract CodeConstants {
    uint256 public constant LOCAL_CHAIN_ID = 31337;

    string constant LOCAL_BASE_URL = "https://resolver.justaname.id/v2";
    address constant LOCAL_INITIAL_OWNER = 0x0987654321098765432109876543210987654321;
    address constant LOCAL_INITIAL_SIGNER = 0x1234567890123456789012345678901234567890;

    address payable public constant TEST_ACCOUNT_ADDRESS = payable(0x70997970C51812dc3A010C7d01b50e0d17dc79C8);
    uint256 public constant TEST_ACCOUNT_PRIVATE_KEY =
        0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d;
}

contract HelperConfig is CodeConstants, Script {
    error HelperConfig__InvalidChainId();

    struct NetworkConfig {
        string baseUrl;
        address initialOwner;
        address initialSigner;
    }

    function getConfigByChainId(uint256 chainId) public pure returns (NetworkConfig memory) {
        if (chainId == LOCAL_CHAIN_ID) {
            return getOrCreateAnvilEthConfig();
        } else {
            revert HelperConfig__InvalidChainId();
        }
    }

    function getConfig() public view returns (NetworkConfig memory) {
        return getConfigByChainId(block.chainid);
    }

    function getOrCreateAnvilEthConfig() public pure returns (NetworkConfig memory) {
        return NetworkConfig({
            baseUrl: LOCAL_BASE_URL,
            initialOwner: LOCAL_INITIAL_OWNER,
            initialSigner: LOCAL_INITIAL_SIGNER
        });
    }
}
