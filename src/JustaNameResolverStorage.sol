// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {OwnableUpgradeable} from "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import {Initializable} from "@openzeppelin-upgradeable/contracts/proxy/utils/Initializable.sol";

contract JustaNameResolverStorage is Initializable, OwnableUpgradeable, UUPSUpgradeable {
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
    function initialize(string calldata baseUrl, address[] calldata _signers, address initialOwner)
        external
        initializer
    {
        __Ownable_init(initialOwner);
        __UUPSUpgradeable_init();

        addUrl(baseUrl);
        addSigners(_signers);
    }

    /**
     * @dev Removes a URL from the list of authorized gateway URLs
     * @param index The index of the URL to remove from the array
     * @notice Only callable by the contract owner
     * @notice This function uses the "swap and pop" pattern for gas-efficient array element removal
     * @notice The URL at the specified index will be replaced with the last URL in the array, then the array is shortened
     * @notice Emits a {DeprecatedUrl} event with the removed URL
     */
    function deprecateUrl(uint256 index) external onlyOwner {
        require(index < s_urls.length, JustaNameResolverV2_IndexOutOfBounds());
        s_urls[index] = s_urls[s_urls.length - 1];
        s_urls.pop();

        emit DeprecatedUrl(s_urls[index]);
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

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    /*//////////////////////////////////////////////////////////////
                            GETTER_FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function getUrl(uint256 index) external view returns (string memory) {
        return s_urls[index];
    }

    function isSigner(address signer) public view returns (bool) {
        return s_signers[signer];
    }

    function getUrls() public view returns (string[] memory) {
        return s_urls;
    }
}
