<a href="https://inverter.network" target="_blank"><img align="right" width="150" height="150" top="100" src="./assets/logo_circle.svg"></a>

# Using the Deterministic Factory

The Inverter Deterministic Factory is a contract that allows for the deterministic deployment of other contracts using the CREATE2 opcode. This guide will help you understand how to interact with the contract through its interface.

## Table of Contents

1. [Public Functions](#public-functions)
2. [Events](#events)
3. [Usage](#usage)
    1. [Converting Existing Scripts](#converting-existing-scripts)

## Public Functions

#### deployWithCreate2

```solidity
function deployWithCreate2(bytes32 salt, bytes calldata code)
    external
    returns (address deploymentAddress);
```

Deploys a contract using CREATE2 with the provided salt and bytecode. This function can only be called by the allowed deployer.

#### computeCreate2Address

```solidity
function computeCreate2Address(bytes32 salt, bytes32 codeHash)
    external
    view
    returns (address deploymentAddress);
```

Calculates and returns the address where a contract would be deployed using CREATE2 with the given salt and bytecode hash.

#### getCodeHash

```solidity
function getCodeHash(bytes memory code)
    external
    pure
    returns (bytes32 codeHash);
```

Helper function to calculate the keccak256 hash of the provided bytecode.

#### setAllowedDeployer

```solidity
function setAllowedDeployer(address _allowedDeployer) external;
```

Sets the address that is allowed to use the factory for deployments. This function can only be called by the contract owner.

## Events

#### DeterministicFactory\_\_AllowedDeployerChanged

```solidity
event DeterministicFactory__AllowedDeployerChanged(
    address indexed newAllowedDeployer
);
```

Emitted when the allowed deployer address is changed.

#### DeterministicFactory\_\_NewDeployment

```solidity
event DeterministicFactory__NewDeployment(
    bytes32 indexed salt,
    address indexed deployment
);
```

Emitted when a new contract is deployed using CREATE2.

## Usage

In general, two things are needed in order to deploy a contract via CREATE2: a bytecode of the contract and a salt. The salt is a `bytes32` variable that can be anything, a number, a hash, a string, etc. It is a practice to choose reasonable values here, i.e.

```solidity
bytes32 salt = keccak256("inverter-deployment-01");
```

This ensures that a salt is not re-used on accident for other deployments that may take place. It is important to re-use the same salt, whenever a deployment on a different network shall arrive at the same address.

Acquiring the bytecode of a contract can be done via multiple ways. As our protocol is developed in Foundry, we'll focus on the simplest way here, which is using the `vm.getCode()` cheatcode in a script:

```solidity
bytes memory contractCode = vm.getCode("ContractName_v1.sol:ContractName_v1");
```

If the contract requires certain `constructor` parameters, these will need to be encoded as well, exactly as they were when the contract was first deployed via this mechanism. Let's assume the contract has the following `constructor`:

```solidity
constructor(address _transactionForwarder) {
    transactionForwarder = _transactionForwarder;
}
```

Given this `constructor`, the final generation of the deployed bytecode looks like this:

```solidity
address trustedForwarder = 0x00...00;
bytes memory args = abi.encode(trustedForwarder);
bytes memory contractCode = vm.getCode("ContractName_v1.sol:ContractName_v1");
bytes memory bytecode = abi.encodePacked(contractCode, args);
```

This `bytecode` variable is then used for the CREATE2-based deployment, together with the `salt`.

In this example, we assume that the Deterministic Factory has already been deployed, which would then be used like this:

```solidity
DeterministicFactory_v1 factory = DeterministicFactory_v1(0x00...00);
address newDeployment = factory.deployWithCreate2(salt, bytecode);
```

If you'd want to know the resulting address beforehand (i.e. to verify whether your inputs are correctly re-creating a known address), you can do so this way:

```solidity
DeterministicFactory_v1 factory = DeterministicFactory_v1(0x00...00);
bytes32 bytecodeHash = factory.getCodeHash(bytecode);
address computedAddress = factory.computeCreate2Address(salt, bytecodeHash);
```

The resulting `computedAddress` will be the same address of a deployment via `deployWithCreate2`, if the same values are used. If the `salt` or `bytecode` change, the address changes as well.

### Converting Existing Scripts

If you have pre-existing scripts and want to make use of a deterministic deployment, a conversion is quite straight-forward. Let's look at this example:

```solidity
// Deploy the Governor_v1.
govImplementation = new Governor_v1();

// Deploy Governance Contract
gov = Governor_v1(
    address(
        new TransparentUpgradeableProxy(
            address(govImplementation),
            communityMultisig,
            bytes("")
        )
    )
);

// Initialize
gov.init(
    communityMultisig,
    teamMultisig,
    timelockPeriod,
    initialFeeManager
);
```

In this example, we'd want the `Governor_v1` contract to be deployed at a deterministic address, to simplify governance actions across different EVM-based chains. As the actual `gov` contract is a `TransparentUpgradeableProxy`, which has a `constructor`, we'd need the also ensure that the `govImplementation` as well as the `communityMultisig` are at the same address on all chains. A re-structured script with the deterministic approach would look like this:

```solidity
// Instantiate Deterministic Factory
DeterministicFactory_v1 factory = DeterministicFactory_v1(0x00...000);

// Define salt that was used for the deployments
bytes32 salt = keccak256("inverter-deployment-01");

// Deploy the Governor_v1.
bytes memory implBytecode = vm.getCode("Governor_v1.sol:Governor_v1");
govImplementation = factory.deployWithCreate2(salt, implBytecode);

// Deploy Governance Contract
bytes memory proxyArgs = abi.encode(address(govImplementation), communityMultisig, bytes(""));
bytes memory proxyCode = vm.getCode("TransparentUpgradeableProxy.sol:TransparentUpgradeableProxy");
bytes memory proxyBytecode = abi.encodePacked(proxyCode, proxyArgs);
gov = Governor_v1(
    address(
            factory.deployWithCreate2(salt, proxyBytecode)
    )
);

// Initialize
gov.init(
    communityMultisig,
    teamMultisig,
    timelockPeriod,
    initialFeeManager
);
```

---

_Disclaimer: This is experimental software and is provided on an "as is" and "as available" basis. We do not give any warranties and will not be liable for any loss incurred through any use of this codebase._
