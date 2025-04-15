// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {OwnableUpgradeable} from "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import {Initializable} from "@openzeppelin-upgradeable/contracts/proxy/utils/Initializable.sol";

import {SignatureVerifier} from "./libs/SignatureVerifier.sol";

import {ISupportsInterface} from "./interfaces/ISupportsInterface.sol";
import {IExtendedResolver} from "./interfaces/IExtendedResolver.sol";
import {IResolverService} from "./interfaces/IResolverService.sol";

/**
 * @dev Implements an ENS resolver that directs all queries to a CCIP read gateway, following EIP 3668 and ENSIP 10 standards.
 * This resolver allows resolutions to be fetched offchain, reducing on-chain data storage and retrieval costs.
 */
contract JustaNameResolverV2 is Initializable, IExtendedResolver, OwnableUpgradeable, UUPSUpgradeable {
    error OffchainLookup(address sender, string[] urls, bytes callData, bytes4 callbackFunction, bytes extraData);
    error JustaNameResolverV2_InvalidSignature();
    error JustaNameResolverV2_IndexOutOfBounds();

    string[] private s_urls;
    mapping(address => bool) private s_signers;

    event NewSigners(address[] signers);
    event DeprecatedSigners(address[] signers);
    event NewUrlAdded(string url);
    event DeprecatedUrl(string url);

    constructor() {
        _disableInitializers();
    }

    /**
     * @dev Initializes the contract replacing the constructor
     * @param baseUrl The base URL for the CCIP read gateway
     * @param _signers Array of initial signer addresses
     * @param initialOwner Address that will be the owner of the contract
     */
    function initialize(string calldata baseUrl, address[] calldata _signers, address initialOwner) external initializer {
        __Ownable_init(initialOwner);
        __UUPSUpgradeable_init();

        addUrl(baseUrl);
        addSigners(_signers);
    }

    /**
     * @dev Updates the base URL used for CCIP read gateway requests
     * @param url The new base URL to set for offchain lookups
     * @notice Only callable by the contract owner
     * @notice Emits a {BaseUrlUpdated} event
     */
    function addUrl(string calldata url) public onlyOwner {
        s_urls.push(url);

        emit NewUrlAdded(url);
    }

    function removeUrl(uint256 index) external onlyOwner {
        require(index < s_urls.length, JustaNameResolverV2_IndexOutOfBounds());
        s_urls[index] = s_urls[s_urls.length - 1];
        s_urls.pop();

        emit DeprecatedUrl(s_urls[index]);
    }

    /**
     * @dev Adds new addresses to the list of authorized signers
     * @param signers Array of signer addresses to add
     * @notice Only callable by the contract owner
     * @notice This function uses assembly for gas optimization when storing multiple addresses
     * @notice Each address in the array will be authorized to sign offchain resolution data
     * @notice Emits a {NewSigners} event
     */
    function addSigners(address[] calldata signers) public onlyOwner {
        assembly {
            let m := mload(0x40) // Cache the free memory pointer.

            let arrOffset := calldataload(0x04)

            let firstElementPos := add(arrOffset, 0x04)

            let arrLen := calldataload(firstElementPos)

            for { let i := 0 } lt(i, arrLen) { i := add(i, 1) } {
                let signerAddress := calldataload(add(firstElementPos, mul(add(i, 1), 0x20)))

                mstore(0x00, signerAddress)
                mstore(0x20, s_signers.slot)

                sstore(keccak256(0x00, 0x40), 1)
            }

            mstore(0x40, m) // Restore the free memory pointer.
        }

        emit NewSigners(signers);
    }

    /**
     * @dev Deprecates addresses from the list of authorized signers
     * @param signers Array of signer addresses to remove
     * @notice Only callable by the contract owner
     * @notice This function uses assembly for gas optimization when removing multiple addresses
     * @notice Each address in the array will no longer be authorized to sign offchain resolution data
     * @notice Emits a {DeprecatedSigners} event
     */
    function deprecateSigners(address[] calldata signers) external onlyOwner {
        assembly {
            let m := mload(0x40) // Cache the free memory pointer.

            let arrOffset := calldataload(0x04)

            let firstElementPos := add(arrOffset, 0x04)

            let arrLen := calldataload(firstElementPos)

            for { let i := 0 } lt(i, arrLen) { i := add(i, 1) } {
                let signerAddress := calldataload(add(firstElementPos, mul(add(i, 1), 0x20)))

                mstore(0x00, signerAddress)
                mstore(0x20, s_signers.slot)

                sstore(keccak256(0x00, 0x40), 0)
            }

            mstore(0x40, m) // Restore the free memory pointer.
        }

        emit DeprecatedSigners(signers);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    /**
     * Resolves a name, as specified by ENSIP 10.
     * @param name The DNS-encoded name to resolve.
     * @param data The ABI encoded data for the underlying resolution function (Eg, addr(bytes32), text(bytes32,string), etc).
     * @return The return data, ABI encoded identically to the underlying function.
     */
    function resolve(bytes calldata name, bytes calldata data) external view override returns (bytes memory) {
        bytes memory callData = abi.encodeWithSelector(IResolverService.resolve.selector, name, data);
        revert OffchainLookup(address(this), s_urls, callData, JustaNameResolverV2.resolveWithProof.selector, callData);
    }

    /**
     * @dev External view function that allows parsing and verification of the offchain response based on previously signed data.
     * This is called by clients to finalize the offchain resolution process.
     */
    function resolveWithProof(bytes calldata response, bytes calldata extraData) external view returns (bytes memory) {
        (address signer, bytes memory result) = SignatureVerifier.verify(extraData, response);
        require(s_signers[signer], JustaNameResolverV2_InvalidSignature());
        return result;
    }

    // External pure function to compute a signature hash for given parameters, using SignatureVerifier
    function makeSignatureHash(address target, uint64 expires, bytes memory request, bytes memory result)
        external
        pure
        returns (bytes32)
    {
        return SignatureVerifier.makeSignatureHash(target, expires, request, result);
    }

    function getUrl(uint256 index) external view returns (string memory) {
        return s_urls[index];
    }

    function isSigner(address signer) external view returns (bool) {
        return s_signers[signer];
    }

    function supportsInterface(bytes4 interfaceID) external pure returns (bool) {
        return interfaceID == type(IExtendedResolver).interfaceId || interfaceID == type(ISupportsInterface).interfaceId;
    }
}
