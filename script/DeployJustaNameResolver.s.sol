pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {JustaNameResolverV2} from "../src/JustaNameResolverV2.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployJustaNameResolverV2 is Script {
    function run() external returns (address) {
        address proxy = deployJustaNameResolverV2();
        return proxy;
    }

    function deployJustaNameResolverV2() public returns (address) {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        address[] memory signers = new address[](1);
        signers[0] = config.initialSigner;

        vm.startBroadcast(config.initialOwner);
        JustaNameResolverV2 resolverV2 = new JustaNameResolverV2();
        ERC1967Proxy proxy = new ERC1967Proxy(address(resolverV2), "");
        JustaNameResolverV2(address(proxy)).initialize(config.baseUrl, signers, config.initialOwner);
        vm.stopBroadcast();

        return address(proxy);
    }
}
