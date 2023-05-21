// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {BaseSetup} from "../BaseSetup.sol";

contract FuzzBase is BaseSetup {
     function setUp() public virtual override {
        super.setUp();
     }
}
