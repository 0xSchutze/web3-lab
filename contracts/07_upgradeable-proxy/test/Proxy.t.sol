// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {UpgradableProxy} from "../src/UpgradableProxy.sol";
import {Counter}   from "../src/CounterV1.sol";
import {CounterV2} from "../src/CounterV2.sol";

// Casting trick: proxy address is cast to the implementation type so Foundry
// can call implementation functions on it — same pattern used in production
// frontends (ethers.js: new Contract(proxyAddr, ImplementationABI, signer)).
contract ProxyTest is Test {
    address bob;   // proxy admin
    address alice; // unprivileged user

    UpgradableProxy public proxy;
    Counter         public counter;
    CounterV2       public counterV2;
    Counter         public proxyAsCounter;
    CounterV2       public proxyAsCounterV2;

    function setUp() public {
        alice = makeAddr("alice");
        bob   = makeAddr("bob");

        counter   = new Counter();
        counterV2 = new CounterV2();

        proxy = new UpgradableProxy(address(counter), bob);

        proxyAsCounter   = Counter(address(proxy));
        proxyAsCounterV2 = CounterV2(address(proxy));
    }

    // Delegatecall routes calls through fallback → implementation correctly.
    function test_DelegatecallWorks() public {
        assertEq(proxyAsCounter.number(), 0);
        proxyAsCounter.increment();
        assertEq(proxyAsCounter.number(), 1);
    }

    // Admin can upgrade; storage state (counter value) survives the upgrade.
    function test_UpgradeToWithAdmin() public {
        proxyAsCounter.increment();

        vm.startPrank(bob);
        proxy.upgradeTo(address(counterV2));
        vm.stopPrank();

        assertEq(proxyAsCounterV2.number(), 1);
    }

    // Non-admin upgrade attempt must revert.
    function test_UpgradeToWithoutAdmin() public {
        proxyAsCounter.increment();

        vm.startPrank(alice);
        vm.expectRevert();
        proxy.upgradeTo(address(counterV2));
        vm.stopPrank();

        assertEq(proxyAsCounter.number(), 1);
    }

    // After transferOwnership: old admin loses privileges, new admin gains them.
    function test_TransferOwnership() public {
        vm.startPrank(bob);
        proxy.transferOwnership(alice);

        vm.expectRevert();
        proxy.upgradeTo(address(counterV2));
        vm.stopPrank();

        vm.startPrank(alice);
        proxy.upgradeTo(address(counterV2));
        vm.stopPrank();
    }
}