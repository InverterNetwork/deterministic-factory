// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Script.sol";

// Import contracts
import {DeterministicFactory_v1} from "src/DeterministicFactory_v1.sol";

contract PrintBytecode is Script {
    address multisig = vm.envAddress("MULTISIG_ADDRESS");

    //--------------------------------------------------------------------------
    /// @notice Generates the Deterministic Factory contract bytecode
    /// @return bytecode The bytecode of the Deterministic Factory
    function run() public virtual returns (bytes memory bytecode) {
        console2.log(
            "-----------------------------------------------------------------------------"
        );
        console2.log("Generating Inverter Deterministic Factory Bytecode...");

        // Check if the MULTISIG_ADDRESS is set to zero, if so
        // abort and inform the user
        if (multisig == address(0)) {
            console2.log(
                "Error, the MULTISIG_ADDRESS is set to zero, the deployment would be unowned and useless!"
            );
            console2.log(
                "Not printing any bytecode. Please check the dev.env file and set the MULTISIG_ADDRESS variable to the correct address."
            );
            console2.log(
                "-----------------------------------------------------------------------------"
            );
            return (new bytes(0));
        }

        bytes memory args = abi.encode(multisig);
        bytes memory code =
            vm.getCode("DeterministicFactory_v1.sol:DeterministicFactory_v1");
        bytecode = abi.encodePacked(code, args);

        console2.log("Argument (owner):", multisig);
        console2.log("Please find the bytecode above.");

        console2.log(
            "-----------------------------------------------------------------------------"
        );

        return (bytecode);
    }
}
