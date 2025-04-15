// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {JustaNameResolverStorage} from "./JustaNameResolverStorage.sol";

import {SignatureVerifier} from "./libs/SignatureVerifier.sol";

import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

import {IExtendedResolver} from "./interfaces/IExtendedResolver.sol";
import {IResolverService} from "./interfaces/IResolverService.sol";

/**
 * @dev Implements an ENS resolver that directs all queries to a CCIP read gateway, following EIP 3668 and ENSIP 10 standards.
 */
contract JustaNameResolverV2 is IExtendedResolver, JustaNameResolverStorage {
    error OffchainLookup(address sender, string[] urls, bytes callData, bytes4 callbackFunction, bytes extraData);
    error JustaNameResolverV2_InvalidSignature();

    /**
     * Resolves a name, as specified by ENSIP 10.
     * @param name The DNS-encoded name to resolve.
     * @param data The ABI encoded data for the underlying resolution function (Eg, addr(bytes32), text(bytes32,string), etc).
     * @return The return data, ABI encoded identically to the underlying function.
     */
    function resolve(bytes calldata name, bytes calldata data) external view override returns (bytes memory) {
        bytes memory callData = abi.encodeWithSelector(IResolverService.resolve.selector, name, data);
        revert OffchainLookup(
            address(this), getUrls(), callData, JustaNameResolverV2.resolveWithProof.selector, callData
        );
    }

    /**
     * @dev External view function that allows parsing and verification of the offchain response based on previously signed data.
     * This is called by clients to finalize the offchain resolution process.
     */
    function resolveWithProof(bytes calldata response, bytes calldata extraData) external view returns (bytes memory) {
        (address signer, bytes memory result) = SignatureVerifier._verify(extraData, response);
        require(isSigner(signer), JustaNameResolverV2_InvalidSignature());
        return result;
    }

    /**
     * @dev External utility function to compute a signature hash for given params
     * @return A bytes32 hash that can be signed by an authorized signer
     */
    function makeSignatureHash(address target, uint64 expires, bytes memory request, bytes memory result)
        external
        pure
        returns (bytes32)
    {
        return SignatureVerifier._makeSignatureHash(target, expires, request, result);
    }

    /**
     * @dev Implements ERC-165 interface detection
     * @param interfaceID The interface identifier to check support for
     * @return true if this contract supports the given interface
     */
    function supportsInterface(bytes4 interfaceID) external pure returns (bool) {
        return interfaceID == type(IERC165).interfaceId || interfaceID == type(IExtendedResolver).interfaceId;
    }
}
