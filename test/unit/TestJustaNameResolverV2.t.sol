// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {Test, console} from "forge-std/Test.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {JustaNameResolverV2} from "../../src/JustaNameResolverV2.sol";
import {JustaNameResolverStorage} from "../../src/JustaNameResolverStorage.sol";
import {DeployJustaNameResolverV2} from "../../script/DeployJustaNameResolver.s.sol";
import {CodeConstants} from "../../script/HelperConfig.s.sol";

contract TestJustaNameResolverV2 is Test, CodeConstants {
    JustaNameResolverV2 public resolverV2;
    DeployJustaNameResolverV2 public deployer;

    string public NEW_URL = "https://new.justaname.id/v2";

    function setUp() public {
        deployer = new DeployJustaNameResolverV2();
        resolverV2 = JustaNameResolverV2(deployer.deployJustaNameResolverV2());
    }
}