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
        assertEq0(address(regular).code, deployed.code);
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
        assertNotEq(keccak256(address(regular).code), keccak256(deployed.code));
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

    // Test whether the deployment authorization system works
    function testDeploymentAuthorizationPassingWorks(
        bytes32 salt,
        address caller
    ) public ensureValidSalt(salt) ensureValidAddress(caller) {
        // We want to try whether the deployment authorization system works
        // as expected, so we need to make sure that the caller is not the
        // allowed deployer
        vm.assume(caller != deterministicFactory.allowedDeployer());

        // Deploy the contract using the deterministic factory, expecting
        // a revert as the caller is not authorized to deploy contracts
        vm.prank(caller);
        vm.expectRevert(
            IDeterministicFactory_v1.DeterministicFactory__NotAllowed.selector
        );
        address deployed =
            deterministicFactory.deployWithCreate2(salt, bytecode);

        // We want to make sure that no one besides the owner can change the
        // allowed deployer
        address random = makeAddr("RandomAddress");
        vm.prank(random);
        vm.expectRevert(
            abi.encodeWithSelector(Ownable__UnauthorizedAccount, random)
        );
        deterministicFactory.setAllowedDeployer(caller);

        // We set the caller as the allowed deployer as the owner
        vm.prank(teamMultiSig);
        vm.expectEmit(true, true, true, true);
        emit IDeterministicFactory_v1
            .DeterministicFactory__AllowedDeployerChanged(caller);
        deterministicFactory.setAllowedDeployer(caller);

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
        assertEq(computed, deployed);
    }

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
        assertNotEq(computed, deployed);
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
