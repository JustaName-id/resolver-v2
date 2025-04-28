// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {Test, console} from "forge-std/Test.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {JustaNameResolverV2} from "../../src/JustaNameResolverV2.sol";
import {JustaNameResolverStorage} from "../../src/JustaNameResolverStorage.sol";
import {DeployJustaNameResolverV2} from "../../script/DeployJustaNameResolver.s.sol";
import {CodeConstants} from "../../script/HelperConfig.s.sol";

contract TestJustaNameResolverStorage is Test, CodeConstants {
    JustaNameResolverV2 public resolverV2;
    DeployJustaNameResolverV2 public deployer;

    string public NEW_URL = "https://new.justaname.id/v2";

    function setUp() public {
        deployer = new DeployJustaNameResolverV2();
        resolverV2 = JustaNameResolverV2(deployer.deployJustaNameResolverV2());
    }

    /*//////////////////////////////////////////////////////////////
                            INITIALIZATION
    //////////////////////////////////////////////////////////////*/
    function test_ShouldInitializeCorrectly() public {
        assertEq(resolverV2.getUrls().length, 1);
        assertEq(resolverV2.getUrls()[0], LOCAL_BASE_URL);

        assertEq(resolverV2.isSigner(LOCAL_INITIAL_SIGNER), true);

        assertEq(resolverV2.owner(), LOCAL_INITIAL_OWNER);
    }

    /*//////////////////////////////////////////////////////////////
                                 URL
    //////////////////////////////////////////////////////////////*/
    function test_ShouldGetUrlsCorrectly() public {
        string[] memory urls = resolverV2.getUrls();
        assertEq(urls.length, 1);
        assertEq(urls[0], LOCAL_BASE_URL);
    }

    function test_ShouldGetUrlCorrectly() public {
        string memory url = resolverV2.getUrl(0);
        assertEq(url, LOCAL_BASE_URL);
    }

    function test_ShouldAddUrlCorrectly() public {
        string[] memory oldUrls = resolverV2.getUrls();

        vm.expectEmit(true, false, false, false, address(resolverV2));
        emit JustaNameResolverStorage.NewUrlAdded(NEW_URL);

        vm.prank(LOCAL_INITIAL_OWNER);
        resolverV2.addUrl(NEW_URL);

        string[] memory newUrls = resolverV2.getUrls();
        assertEq(newUrls.length, oldUrls.length + 1);
        assertEq(newUrls[oldUrls.length], NEW_URL);
    }

    function test_ShouldNotAddUrlIfNotOwner(address notOwner) public {
        vm.assume(notOwner != LOCAL_INITIAL_OWNER);

        vm.prank(notOwner);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, notOwner));
        resolverV2.addUrl(NEW_URL);
    }

    function test_ShouldDeprecateUrlCorrectly(uint256 index) public {
        string[] memory oldUrls = resolverV2.getUrls();

        vm.assume(index < oldUrls.length);

        vm.expectEmit(true, false, false, false, address(resolverV2));
        emit JustaNameResolverStorage.DeprecatedUrl(oldUrls[index]);

        vm.prank(LOCAL_INITIAL_OWNER);
        resolverV2.deprecateUrl(index);

        string[] memory newUrls = resolverV2.getUrls();
        assertEq(newUrls.length, oldUrls.length - 1);
    }

    function test_ShouldNotDeprecateUrlIfNotOwner(uint256 index, address notOwner) public {
        string[] memory oldUrls = resolverV2.getUrls();
        vm.assume(index < oldUrls.length);

        vm.prank(notOwner);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, notOwner));
        resolverV2.deprecateUrl(index);
    }

    function test_ShouldRevertIfIndexOutOfBounds(uint256 index) public {
        string[] memory urls = resolverV2.getUrls();
        vm.assume(index >= urls.length);

        vm.prank(LOCAL_INITIAL_OWNER);
        vm.expectRevert(abi.encodeWithSelector(JustaNameResolverStorage.JustaNameResolverV2_IndexOutOfBounds.selector));
        resolverV2.deprecateUrl(index);
    }

    /*//////////////////////////////////////////////////////////////
                                 SIGNERS
    //////////////////////////////////////////////////////////////*/
}
