// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

interface IResolverService {
    function resolve(bytes calldata name, bytes calldata data)
        external
        view
        returns (bytes memory result, uint64 expires, bytes memory sig);
}
