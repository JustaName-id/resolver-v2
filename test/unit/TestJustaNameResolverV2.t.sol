// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {Test, console} from "forge-std/Test.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {IExtendedResolver} from "../../src/interfaces/IExtendedResolver.sol";
import {IResolverService} from "../../src/interfaces/IResolverService.sol";
import {SignatureVerifier} from "../../src/libs/SignatureVerifier.sol";
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

        address[] memory signers = new address[](1);
        signers[0] = TEST_ACCOUNT_ADDRESS;

        vm.prank(resolverV2.owner());
        JustaNameResolverStorage(address(resolverV2)).addSigners(signers);
    }

    /*//////////////////////////////////////////////////////////////
                                RESOLVE
    //////////////////////////////////////////////////////////////*/
    function test_ResolveShouldRevertWithOffchainLookup(bytes memory name, bytes memory data) public {
        bytes memory expectedCallData = abi.encodeWithSelector(IResolverService.resolve.selector, name, data);

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
                            RESOLVE WITH PROOF
    //////////////////////////////////////////////////////////////*/
    function test_ShouldResolveWithProofCorrectly(bytes memory name, bytes memory data, uint64 expires) public view {
        vm.assume(expires >= block.timestamp);

        bytes memory request = abi.encodeWithSelector(IResolverService.resolve.selector, name, data);

        bytes memory result = abi.encode(data);

        bytes32 signatureHash = resolverV2.makeSignatureHash(address(resolverV2), expires, request, result);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(TEST_ACCOUNT_PRIVATE_KEY, signatureHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        bytes memory response = abi.encode(result, expires, signature);

        bytes memory returnedResult = resolverV2.resolveWithProof(response, request);
        assertEq(keccak256(returnedResult), keccak256(result));
    }

    function test_ResolveWithProofShouldFailIfExpired(bytes memory name, bytes memory data, uint64 expires) public {
        vm.assume(expires < block.timestamp);

        bytes memory request = abi.encodeWithSelector(IResolverService.resolve.selector, name, data);

        bytes memory result = abi.encode(data);

        bytes32 signatureHash = resolverV2.makeSignatureHash(address(resolverV2), expires, request, result);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(TEST_ACCOUNT_PRIVATE_KEY, signatureHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        bytes memory response = abi.encode(result, expires, signature);

        vm.expectRevert(abi.encodeWithSelector(SignatureVerifier.SignatureVerifier_SignatureExpired.selector));
        resolverV2.resolveWithProof(response, request);
    }

    function test_ResolveWithProofShouldFailIfNotSigner(
        bytes memory name,
        bytes memory data,
        uint64 expires,
        uint256 notSignerPrivateKey
    ) public {
        vm.assume(expires >= block.timestamp);
        vm.assume(notSignerPrivateKey != TEST_ACCOUNT_PRIVATE_KEY);
        // Private key must be less than the Secp256k1 curve order
        vm.assume(notSignerPrivateKey < 115792089237316195423570985008687907852837564279074904382605163141518161494337);
        // Private key must not be 0
        vm.assume(notSignerPrivateKey != 0);

        bytes memory request = abi.encodeWithSelector(IResolverService.resolve.selector, name, data);

        bytes memory result = abi.encode(data);
        bytes32 signatureHash = resolverV2.makeSignatureHash(address(resolverV2), expires, request, result);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(notSignerPrivateKey, signatureHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        bytes memory response = abi.encode(result, expires, signature);

        vm.expectRevert(abi.encodeWithSelector(JustaNameResolverV2.JustaNameResolverV2_InvalidSignature.selector));
        resolverV2.resolveWithProof(response, request);
    }

    /*//////////////////////////////////////////////////////////////
                            SIGNATURE HASH
    //////////////////////////////////////////////////////////////*/
    // TODO: make sure that this is enough to test the signature hash
    function test_ShouldReturnCorrectSignatureHash(uint64 expires, bytes memory request, bytes memory result)
        public
        view
    {
        bytes32 signatureHash =
            resolverV2.makeSignatureHash(address(resolverV2), uint64(block.timestamp + expires), request, result);

        bytes32 expectedHash = keccak256(
            abi.encodePacked(
                hex"1900", address(resolverV2), uint64(block.timestamp + expires), keccak256(request), keccak256(result)
            )
        );

        assertEq(signatureHash, expectedHash);
    }

    /*//////////////////////////////////////////////////////////////
                            SUPPORTS INTERFACE
    //////////////////////////////////////////////////////////////*/
    function test_ShouldReturnTrueIfSupportsInterface() public view {
        assertEq(resolverV2.supportsInterface(type(IERC165).interfaceId), true);
        assertEq(resolverV2.supportsInterface(type(IExtendedResolver).interfaceId), true);
    }

    function test_ShouldReturnFalseIfDoesNotSupportInterface(bytes4 interfaceId) public view {
        vm.assume(interfaceId != type(IERC165).interfaceId);
        vm.assume(interfaceId != type(IExtendedResolver).interfaceId);

        assertEq(resolverV2.supportsInterface(interfaceId), false);
    }
}
