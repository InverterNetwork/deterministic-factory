// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity 0.8.23;

// Internal Interfaces
import {IDeterministicFactory_v1} from
    "src/interfaces/IDeterministicFactory_v1.sol";

// External Dependencies
import {Ownable2Step, Ownable} from "@oz/access/Ownable2Step.sol";
import {Create2} from "@oz/utils/Create2.sol";

/**
 * @title   Deterministic Deployment Factory
 *
 * @notice  This contract is a factory for deploying contracts using the CREATE2 opcode,
 *          allowing us to deploy some of our contract at the same address for each EVM-
 *          compatible network.
 *
 * @dev     We limit the deployment to a specific address ('allowedDeployer'), as otherwise
 *          anyone could deploy our contracts at the addresses we use. This can be
 *          problematic for contracts that are initialized, i.e. where the owner is only set
 *          after deployment, which would hand them ownership of the contracts. We intend
 *          to set this 'allowedDeployer' to the deployment account we use, and then
 *          set it to the zero address afterwards (until the next deployment takes place).
 *
 * @custom:security-contact security@inverter.network
 *                          In case of any concerns or findings, please refer to our Security Policy
 *                          at security.inverter.network or email us directly!
 *
 * @author  Inverter Network
 */
contract DeterministicFactory_v1 is IDeterministicFactory_v1, Ownable2Step {
    //--------------------------------------------------------------------------
    // Variables

    /// @dev The address that is allowed to use the factory.
    address public allowedDeployer;

    //--------------------------------------------------------------------------
    // Modifiers

    /// @notice Modifier to restrict access to the allowed address.
    modifier onlyAllowed() {
        if (msg.sender != allowedDeployer) {
            revert DeterministicFactory__NotAllowed();
        }
        _;
    }

    //--------------------------------------------------------------------------
    // Constructor

    /// @notice Sets the initial owner of the contract
    constructor(address _initialOwner) Ownable(_initialOwner) {}

    //--------------------------------------------------------------------------
    // Public Functions

    /// @inheritdoc IDeterministicFactory_v1
    function setAllowedDeployer(address _allowedDeployer) external onlyOwner {
        allowedDeployer = _allowedDeployer;
        emit DeterministicFactory__AllowedDeployerChanged(_allowedDeployer);
    }

    /// @inheritdoc IDeterministicFactory_v1
    function deployWithCreate2(bytes32 salt, bytes calldata code)
        external
        onlyAllowed
        returns (address deploymentAddress)
    {
        deploymentAddress = Create2.deploy(0, salt, code);
        emit DeterministicFactory__NewDeployment(salt, deploymentAddress);
    }

    /// @inheritdoc IDeterministicFactory_v1
    function computeCreate2Address(bytes32 salt, bytes32 codeHash)
        external
        view
        returns (address deploymentAddress)
    {
        // Calculate the address that a contract with the
        // provided codeHash and salt would be deployed at.
        deploymentAddress = Create2.computeAddress(salt, codeHash);
    }

    /// @inheritdoc IDeterministicFactory_v1
    function getCodeHash(bytes memory code)
        external
        pure
        returns (bytes32 codeHash)
    {
        return keccak256(abi.encodePacked(code));
    }
}
