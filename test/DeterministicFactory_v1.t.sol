// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

// Internal Dependencies
import {
    DeterministicFactory_v1,
    IDeterministicFactory_v1
} from "src/DeterministicFactory_v1.sol";

// Mocks
import {ContractMock} from "test/mocks/ContractMock.sol";

contract DeterministicFactoryV1Test is Test {
    //--------------------------------------------------------------------------
    // Variables and Constants

    // Instance of the deterministic factory
    DeterministicFactory_v1 internal deterministicFactory;

    // Underlying deployed contract
    ContractMock regular;

    // Addresses for testing purposes
    address internal trustedForwarder = makeAddr("TrustedForwarder");
    address internal teamMultiSig = makeAddr("TeamMultiSig");
    address internal caller1 = makeAddr("Caller1");

    // Error signatures
    bytes4 internal constant Create2__Create2EmptyBytecode =
        bytes4(keccak256("Create2EmptyBytecode()"));
    bytes4 internal constant Create2__FailedDeployment =
        bytes4(keccak256("FailedDeployment()"));
    bytes4 internal constant Ownable__UnauthorizedAccount =
        bytes4(keccak256("OwnableUnauthorizedAccount(address)"));

    // Variables used for testing
    bytes internal args = abi.encode(trustedForwarder);
    bytes internal code = vm.getCode("ContractMock.sol:ContractMock");
    bytes internal bytecode = abi.encodePacked(code, args);

    //--------------------------------------------------------------------------
    // Setup

    function setUp() public {
        // Set up a new deterministic factory
        deterministicFactory = new DeterministicFactory_v1(teamMultiSig);

        // Set the caller1 as the allowed deployer
        vm.prank(teamMultiSig);
        deterministicFactory.setAllowedDeployer(caller1);

        // Prepare tests with a regular deployment to compare against
        regular = new ContractMock(trustedForwarder);
    }

    //--------------------------------------------------------------------------
    // Tests

    /*
    Test Deployment
    ├── When the caller is the allowed deployer
    │   ├── When the bytecode is not empty
    │   │   ├── When the contract does not already exist at the target address
    │   │   │   └── It should deploy the contract successfully
    │   │   │       └── It should emit the DeterministicFactory__NewDeployment event
    │   │   └── When the contract already exists at the target address
    │   │       └── It should revert with Create2__FailedDeployment
    │   └── When the bytecode is empty
    │       └── It should revert with Create2__Create2EmptyBytecode
    └── When the caller is not the allowed deployer
        └── It should revert with DeterministicFactory__NotAllowed
    */

    // Test whether the deployment creates the correct contract
    function testDeploymentCreatesCorrectContract(bytes32 salt)
        public
        ensureValidSalt(salt)
    {
        // Calculate the address of the contract with the provided salt
        address computed = computeAddress(salt);

        // Deploy the contract using the deterministic factory
        vm.prank(caller1);
        vm.expectEmit(true, true, true, true);
        emit IDeterministicFactory_v1.DeterministicFactory__NewDeployment(
            salt, computed
        );
        address deployed =
            deterministicFactory.deployWithCreate2(salt, bytecode);

        // Expect that the bytecode of the regular deployment is the same
        // as the bytecode of the deployment using the deterministic factory
        assertEq0(
            address(regular).code,
            deployed.code,
            "Deployed contract bytecode should match the regular deployment"
        );
    }

    // Test whether the deployment creates the incorrect contract given
    // wrong/different constructor arguments compared to a regular deployment
    function testDeploymentCreatesIncorrectContractWithWrongArguments(
        bytes32 salt
    ) public ensureValidSalt(salt) {
        // Prepare the bytecode with the wrong arguments
        bytes memory argsWrong =
            abi.encode(makeAddr("IncorrectTrustedForwarder"));
        bytes memory bytecodeWrong = abi.encodePacked(code, argsWrong);

        // Deploy the contract using the deterministic factory
        vm.prank(caller1);
        address deployed =
            deterministicFactory.deployWithCreate2(salt, bytecodeWrong);

        // Expect that the bytecode of the regular deployment is not the same
        // as the bytecode of the deployment using the deterministic factory
        assertNotEq(
            keccak256(address(regular).code),
            keccak256(deployed.code),
            "Deployed contract bytecode should not match the regular deployment when using incorrect arguments"
        );
    }

    // Test whether the deployment fails if the contract already exists
    // at the address
    function testDeploymentFailsIfContractExists(bytes32 salt)
        public
        ensureValidSalt(salt)
    {
        // Deploy the contract using the deterministic factory
        vm.prank(caller1);
        deterministicFactory.deployWithCreate2(salt, bytecode);

        // Retry to deploy the contract using the deterministic factory
        // this time, expecting a revert as the contract already exists
        vm.prank(caller1);
        vm.expectRevert(Create2__FailedDeployment);
        deterministicFactory.deployWithCreate2(salt, bytecode);
    }

    // Test whether the deployment fails if the provided bytecode is empty
    function testDeploymentFailsIfBytecodeEmpty(bytes32 salt)
        public
        ensureValidSalt(salt)
    {
        // Create an empty byte code
        bytes memory emptyBytecode;

        // Deploy the contract using the deterministic factory, expecting
        // a revert as the bytecode of the deployed contract is empty
        vm.prank(caller1);
        vm.expectRevert(Create2__Create2EmptyBytecode);
        deterministicFactory.deployWithCreate2(salt, emptyBytecode);
    }

    // Test whether the deployment fails if the caller is not authorized
    function testDeploymentFailsIfCallerUnauthorized(
        bytes32 salt,
        address caller
    ) public ensureValidSalt(salt) ensureValidAddress(caller) {
        // We want to try whether the deployment fails if the caller is not
        // authorized to deploy contracts using the deterministic factory, so
        // we need to make sure that the caller is not the allowed deployer
        vm.assume(caller != deterministicFactory.allowedDeployer());

        // Deploy the contract using the deterministic factory, expecting
        // a revert as the caller is not authorized to deploy contracts
        vm.prank(caller);
        vm.expectRevert(
            IDeterministicFactory_v1.DeterministicFactory__NotAllowed.selector
        );
        deterministicFactory.deployWithCreate2(salt, bytecode);
    }

    /*
    Test setAllowedDeployer
    ├── When the caller is the owner
    │   └── It should set the new allowed deployer
    │       └── It should emit the DeterministicFactory__AllowedDeployerChanged event
    └── When the caller is not the owner
        └── It should revert with OwnableUnauthorizedAccount
    */

    // Test whether the deployment authorization system works
    function testDeploymentAuthorizationPassingWorks(
        bytes32 salt,
        address caller
    ) public ensureValidSalt(salt) ensureValidAddress(caller) {
        // Cache the allowed deployer
        address currentAllowedDeployer = deterministicFactory.allowedDeployer();

        // We want to try whether the deployment authorization system works
        // as expected, so we need to make sure that the caller is not the
        // allowed deployer
        vm.assume(caller != currentAllowedDeployer);

        // Deploy the contract using the deterministic factory, expecting
        // a revert as the caller is not authorized to deploy contracts
        vm.prank(caller);
        vm.expectRevert(
            IDeterministicFactory_v1.DeterministicFactory__NotAllowed.selector
        );
        address deployed =
            deterministicFactory.deployWithCreate2(salt, bytecode);
        assertEq(
            currentAllowedDeployer,
            deterministicFactory.allowedDeployer(),
            "Allowed Deployer shouldn't have changed."
        );

        // We want to make sure that no one besides the owner can change the
        // allowed deployer
        address random = makeAddr("RandomAddress");
        vm.prank(random);
        vm.expectRevert(
            abi.encodeWithSelector(Ownable__UnauthorizedAccount, random)
        );
        deterministicFactory.setAllowedDeployer(caller);
        assertEq(
            currentAllowedDeployer,
            deterministicFactory.allowedDeployer(),
            "Allowed Deployer shouldn't have changed."
        );

        // We set the caller as the allowed deployer as the owner
        vm.prank(teamMultiSig);
        vm.expectEmit(true, true, true, true);
        emit IDeterministicFactory_v1
            .DeterministicFactory__AllowedDeployerChanged(caller);
        deterministicFactory.setAllowedDeployer(caller);
        address newAllowedDeployer = deterministicFactory.allowedDeployer();
        assertNotEq(
            currentAllowedDeployer,
            newAllowedDeployer,
            "Allowed Deployer should have changed."
        );
        assertEq(
            newAllowedDeployer,
            caller,
            "Allowed Deployer should be the passed address."
        );

        // Retry to deploy the contract using the deterministic factory
        // this time, expecting a successful deployment as the caller is
        // now the allowed deployer
        vm.prank(caller);
        vm.expectEmit(true, false, true, true);
        emit IDeterministicFactory_v1.DeterministicFactory__NewDeployment(
            salt, address(0)
        );
        deployed = deterministicFactory.deployWithCreate2(salt, bytecode);
    }

    // Test whether the address calculation is accurate
    function testAddressCalculationIsAccurate(bytes32 salt)
        public
        ensureValidSalt(salt)
    {
        // Calculate the address of the contract with the provided salt
        address computed = computeAddress(salt);

        // Deploy the contract using the deterministic factory
        vm.prank(caller1);
        vm.expectEmit(true, true, true, true);
        emit IDeterministicFactory_v1.DeterministicFactory__NewDeployment(
            salt, computed
        );
        address deployed =
            deterministicFactory.deployWithCreate2(salt, bytecode);

        // Expect that the computed address is the same as the deployed address
        assertEq(
            computed,
            deployed,
            "Computed address should match the deployed address"
        );
    }

    /*
    Test Address Calculation Accuracy
    ├── It should accurately predict the deployment address
    └── It should return different addresses for different bytecode or constructor arguments
    */

    // Test whether the address calculation is working as expected
    // given different values
    function testAddressCalculationWithDifferentValues(bytes32 salt)
        public
        ensureValidSalt(salt)
    {
        // Calculate the address of the contract with the provided salt
        address computed = computeAddress(salt);

        // Prepare the bytecode with the wrong arguments
        bytes memory argsWrong =
            abi.encode(makeAddr("IncorrectTrustedForwarder"));
        bytes memory bytecodeWrong = abi.encodePacked(code, argsWrong);

        // Deploy the contract using the deterministic factory, using the
        // wrong bytecode
        vm.prank(caller1);
        address deployed =
            deterministicFactory.deployWithCreate2(salt, bytecodeWrong);

        // Expect that the computed address is not the same as the deployed
        // address as the bytecode is different due to the wrong arguments
        assertNotEq(
            computed,
            deployed,
            "Computed address should not match the deployed address when using different bytecode"
        );
    }

    /*
    Test computeCreate2Address
    ├── It should correctly compute the address for a given salt and code hash
    ├── It should return different addresses for different salts
    └── It should match the address of an actually deployed contract
    */

    // Test whether the computeCreate2Address function returns the correct address
    // for a given salt and code hash
    function testComputeCreate2Address() public {
        bytes32 salt = bytes32(uint(1));
        bytes32 codeHash = keccak256(abi.encodePacked(code));

        // Calculate the address of the contract with the provided salt
        address computedAddress =
            deterministicFactory.computeCreate2Address(salt, codeHash);

        // Expect that the computed address is not zero
        assertTrue(
            computedAddress != address(0), "Computed address should not be zero"
        );
    }

    // Test whether the computeCreate2Address function returns different addresses
    // for different salts
    function testComputeCreate2AddressDifferentSalts() public {
        bytes32 salt1 = bytes32(uint(1));
        bytes32 salt2 = bytes32(uint(2));
        bytes32 codeHash = keccak256(abi.encodePacked(code));

        // Calculate the addresses of the contracts with the provided salts
        address address1 =
            deterministicFactory.computeCreate2Address(salt1, codeHash);
        address address2 =
            deterministicFactory.computeCreate2Address(salt2, codeHash);

        // Expect that the computed addresses are different
        assertNotEq(
            address1,
            address2,
            "Different salts should result in different addresses"
        );
    }

    // Test whether the computeCreate2Address function returns different addresses
    // for different code hashes
    function testComputeCreate2AddressDifferentCodeHashes() public {
        // Prepare different code hashes
        bytes32 salt = bytes32(uint(1));
        bytes memory testCode1 = bytes("inverter-deterministic-factory-1");
        bytes memory testCode2 = bytes("inverter-deterministic-factory-2");
        bytes32 codeHash1 = keccak256(abi.encodePacked(testCode1));
        bytes32 codeHash2 = keccak256(abi.encodePacked(testCode2));

        // Calculate the addresses of the contracts with the provided code hashes
        address address1 =
            deterministicFactory.computeCreate2Address(salt, codeHash1);
        address address2 =
            deterministicFactory.computeCreate2Address(salt, codeHash2);

        // Expect that the computed addresses are different
        assertNotEq(
            address1,
            address2,
            "Different code hashes should result in different addresses"
        );
    }

    /*
    Test getCodeHash
    ├── It should correctly compute the keccak256 hash of the given bytecode
    ├── It should return the same hash for identical bytecode
    └── It should return different hashes for different bytecode
    */

    // Test whether the getCodeHash function returns the correct hash
    function testGetCodeHash() public {
        // Calculate the expected hash of the provided bytecode
        bytes32 expectedHash = keccak256(abi.encodePacked(code));

        // Retrieve the code hash of the provided bytecode
        bytes32 resultHash = deterministicFactory.getCodeHash(code);

        // Expect that the result hash is the same as the expected hash
        assertEq(
            resultHash,
            expectedHash,
            "getCodeHash should return the correct keccak256 hash"
        );
    }

    // Test whether the getCodeHash function returns consistent results
    // for the same input
    function testGetCodeHashConsistency() public {
        // Calculate the hash of the provided bytecode twice
        bytes32 hash1 = deterministicFactory.getCodeHash(code);
        bytes32 hash2 = deterministicFactory.getCodeHash(code);

        // Expect that the two hashes are the same
        assertEq(
            hash1,
            hash2,
            "getCodeHash should return consistent results for the same input"
        );
    }

    // Test whether the getCodeHash function returns different results
    // for different inputs
    function testGetCodeHashDifferentInputs() public {
        // Prepare different code hashes
        bytes memory testCode1 = bytes("inverter-deterministic-factory-1");
        bytes memory testCode2 = bytes("inverter-deterministic-factory-2");

        // Calculate the hashes of the provided bytecodes
        bytes32 hash1 = deterministicFactory.getCodeHash(testCode1);
        bytes32 hash2 = deterministicFactory.getCodeHash(testCode2);

        // Expect that the two hashes are different
        assertNotEq(
            hash1,
            hash2,
            "getCodeHash should return different hashes for different inputs"
        );
    }

    //--------------------------------------------------------------------------
    // Internal Helpers and Modifier

    // Helper function to compute the address of a contract given
    // a salt, with the already known bytecode
    function computeAddress(bytes32 _salt) internal view returns (address) {
        // Calculate the code hash of the bytecode
        bytes32 codeHash = deterministicFactory.getCodeHash(bytecode);

        // Calculate the address that a contract with the provided codeHash
        return deterministicFactory.computeCreate2Address(_salt, codeHash);
    }

    // Helper function to ensure that the address is valid and not
    // accidentally set to a "reserved" address
    function _ensureValidAddress(address _address) internal {
        vm.assume(_address != address(0));
        vm.assume(_address != address(this));
        vm.assume(_address != address(deterministicFactory));
        vm.assume(_address != address(regular));
        vm.assume(_address != caller1);
        vm.assume(_address != trustedForwarder);
        vm.assume(_address != teamMultiSig);
    }

    // Modifier to ensure that the salt is valid
    modifier ensureValidSalt(bytes32 _salt) {
        _ensureValidAddress(computeAddress(_salt));
        _;
    }

    // Modifier to ensure that the address is valid
    modifier ensureValidAddress(address _address) {
        _ensureValidAddress(_address);
        _;
    }
}
