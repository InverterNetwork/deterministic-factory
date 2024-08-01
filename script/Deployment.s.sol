// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Script.sol";

// Import contracts
import {DeterministicFactory_v1} from "src/DeterministicFactory_v1.sol";

contract Deployment is Script {
    uint deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
    address deployer = vm.addr(deployerPrivateKey);

    address multisig = vm.envAddress("MULTISIG_ADDRESS");

    //--------------------------------------------------------------------------
    /// @notice Deploys the Deterministic Factory contract
    /// @return deterministicFactory The address of the deployed Deterministic Factory
    function run() public virtual returns (address deterministicFactory) {
        console2.log(
            "-----------------------------------------------------------------------------"
        );
        console2.log("Deploy Inverter Deterministic Factory...");

        if (multisig == address(0)) {
            console2.log("No MULTISIG_ADDRESS set, using deployer as owner.");
            multisig = deployer;
        }

        vm.startBroadcast(deployerPrivateKey);
        {
            deterministicFactory =
                address(new DeterministicFactory_v1(multisig));
        }

        console2.log("Ownership of the Factory is set to:", multisig);
        console2.log("Deployed Deterministic Factory at:", deterministicFactory);
        console2.log(
            "-----------------------------------------------------------------------------"
        );

        return (deterministicFactory);
    }
}
