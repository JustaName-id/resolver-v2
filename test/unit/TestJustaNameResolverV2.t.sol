// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {Test, console} from "forge-std/Test.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {IExtendedResolver} from "../../src/interfaces/IExtendedResolver.sol";
import {IResolverService} from "../../src/interfaces/IResolverService.sol";

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

    /*//////////////////////////////////////////////////////////////
                                RESOLVE
    //////////////////////////////////////////////////////////////*/
    function test_ResolveShouldRevertWithOffchainLookup(bytes memory name, bytes memory data) public {
        bytes memory expectedCallData = abi.encodeWithSelector(
            IResolverService.resolve.selector,
            name,
            data
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                JustaNameResolverV2.OffchainLookup.selector,
                address(resolverV2),
                resolverV2.getUrls(),
                expectedCallData,
                JustaNameResolverV2.resolveWithProof.selector,
                expectedCallData
            )
        );
        resolverV2.resolve(name, data);
    }

    /*//////////////////////////////////////////////////////////////
                            SIGNATURE HASH
    //////////////////////////////////////////////////////////////*/
    // TODO: make sure that this is enough to test the signature hash
    function test_ShouldReturnCorrectSignatureHash(uint64 expires, bytes memory request, bytes memory result) public {
        bytes32 signatureHash = resolverV2.makeSignatureHash(
            address(resolverV2), 
            uint64(block.timestamp + expires), 
            request, 
            result
        );
        
        bytes32 expectedHash = keccak256(
            abi.encodePacked(
                hex"1900", 
                address(resolverV2), 
                uint64(block.timestamp + expires), 
                keccak256(request), 
                keccak256(result)
            )
        );
        
        assertEq(signatureHash, expectedHash);
    }

    /*//////////////////////////////////////////////////////////////
                            SUPPORTS INTERFACE
    //////////////////////////////////////////////////////////////*/
    function test_ShouldReturnTrueIfSupportsInterface() public {
        assertEq(resolverV2.supportsInterface(type(IERC165).interfaceId), true);
        assertEq(resolverV2.supportsInterface(type(IExtendedResolver).interfaceId), true);
    }

    function test_ShouldReturnFalseIfDoesNotSupportInterface(bytes4 interfaceId) public {
        vm.assume(interfaceId != type(IERC165).interfaceId);
        vm.assume(interfaceId != type(IExtendedResolver).interfaceId);

        assertEq(resolverV2.supportsInterface(interfaceId), false);
    }
}