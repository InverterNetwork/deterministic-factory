// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.0;

contract ContractMock {
    address public immutable someone;

    constructor(address _someone) {
        someone = _someone;
    }
}
