<a href="https://inverter.network" target="_blank"><img align="right" width="150" height="150" top="100" src="./assets/logo_circle.svg"></a>

# Inverter Deterministic Deployment Factory

_Inverter is the pioneering web3 protocol for token economies, enabling conditional token issuance, dynamic utility management, and token distribution. Build, customize, and innovate with Inverter's modular logic and extensive web3 interoperability._

This repository provides a Deterministic Deployment Factory, written in Solidity. It can be used, to deploy contracts across different EVM-based networks on the same address, given the same `salt` is used as well as the same `bytecode` deployed.

## Installation

The Inverter Deterministic Deployment Factory smart contracts are developed using the [foundry toolchain](https://getfoundry.sh)

1. Clone the repository
2. `cd` into the repository
3. Run `make install` to install contract dependencies
4. (_Optional_) Run `source dev.env` to set up environment variables

## Usage

#### Usage of the Factory

If you are looking to make use of the Deterministic Factory yourself, you can find our documentation on its use [here](./USAGE.md).

#### Usage of the Project

Common tasks are executed through a `Makefile`. The most common commands are:

-   `make build` to compile the project.
-   `make test` to run the test suite.
-   `make pre-commit` to ensure all of the development requirements are met, such as
    -   the Foundry Formatter has been run.
    -   the scripts are all working.
    -   the tests all run without any issues.

Additionally, the `Makefile` supports a help command, i.e. `make help`.

```
$ make help
> build                    Build project
> clean                    Remove build artifacts
> test                     Run whole testsuite
> update                   Update dependencies
> [...]
```

## Dependencies

-   [OpenZeppelin Contracts](https://github.com/OpenZeppelin/openzeppelin-contracts)

## Safety

Our [Security Policy](./SECURITY.md) provides details about our Security Guidelines, audits, and more. If you have discovered a potential security vulnerability within the Inverter Protocol, please report it to us by emailing [security@inverter.network](mailto:security@inverter.network).

---

_Disclaimer: This is experimental software and is provided on an "as is" and "as available" basis. We do not give any warranties and will not be liable for any loss incurred through any use of this codebase._
