// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Script.sol";

// Import contracts
import {DeterministicFactory_v1} from "src/DeterministicFactory_v1.sol";

contract SetAllowedDeployer is Script {
    uint deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
    address deployer = vm.addr(deployerPrivateKey);

    DeterministicFactory_v1 deterministicFactory =
        DeterministicFactory_v1(vm.envAddress("DEPLOYED_DETERMINISTIC_FACTORY"));
    address newDeployer = vm.envAddress("NEW_DEPLOYER");

    //--------------------------------------------------------------------------
    /// @notice Sets a new allowed deployer in the Inverter Deterministic Factory
    function run() public virtual {
        console2.log(
            "-----------------------------------------------------------------------------"
        );
        console2.log(
            "Set a new allowed deployer in the Inverter Deterministic Factory..."
        );

        if (address(deterministicFactory) == address(0)) {
            console2.log("No DEPLOYED_DETERMINISTIC_FACTORY set, aborting.");
            return;
        }

        if (newDeployer == address(0)) {
            console2.log("No NEW_DEPLOYER set, setting deployer to address(0).");
            console2.log(
                "No one can deploy contracts using the factory. If you didn't intend this, set NEW_DEPLOYER to the address of the intended deployer in the .env file."
            );
        }

        vm.startBroadcast(deployerPrivateKey);
        {
            deterministicFactory.setAllowedDeployer(newDeployer);
        }

        console2.log("Allowed deployer of the factory set to:", newDeployer);
        console2.log(
            "-----------------------------------------------------------------------------"
        );
    }
}
