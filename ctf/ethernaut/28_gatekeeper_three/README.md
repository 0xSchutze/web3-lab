# Level 28: Gatekeeper Three

**Target:** [GatekeeperThree.sol](./GatekeeperThree.sol)
**Exploit:** [exploit.sol](./exploit.sol)

## Vulnerability

`GatekeeperThree` contains a constructor with a typo (`construct0r`) that makes it a callable public function, allowing any contract to seize ownership. Combined with a predictable `block.timestamp`-based password and an ETH-send failure trap, all three gates can be bypassed in a single transaction.

## Key Concepts

**Typo Constructor (construct0r)**
In Solidity ≥ 0.5.0, constructors must be declared with the `constructor` keyword. A function named anything else — including `construct0r` — compiles as an ordinary `public` function callable by anyone at any time.

**block.timestamp Predictability**
`SimpleTrick` initialises its `private password` to `block.timestamp` at deployment time. If the attacker deploys the trick contract and submits the password within the same block, the timestamps are identical and the check passes trivially.

**ETH send() Failure as a Gate**
`gateThree` requires that `payable(owner).send(0.001 ether)` returns `false`. Because the attacker contract (now the owner) declares no `receive` or `fallback` function, every ETH push to it reverts, satisfying the condition.

**msg.sender vs tx.origin Separation**
`gateOne` enforces `msg.sender == owner` AND `tx.origin != owner`. Routing the call through an intermediate contract naturally satisfies both: `msg.sender` is the attacker contract (the new owner) while `tx.origin` is the EOA.

## Root Cause

The root cause is the misnamed initialiser function. Because `construct0r` is public and ownerless, ownership bootstrapping is completely open to any caller. The remaining gates rely on weak entropy (`block.timestamp`) and an assumed ETH-receive capability in the owner that is never enforced.

## Exploit

The attack is executed atomically in four ordered steps inside `Exploit.attack()`:

| Step | Call | Effect |
|------|------|--------|
| 1 | `createTrick()` | Deploys `SimpleTrick`, sets `password = block.timestamp` |
| 2 | `construct0r()` | Sets `owner = address(this)` (attacker contract) |
| 3 | `getAllowance(block.timestamp)` | Passwords match → `allowEntrance = true` |
| 4 | `call{value: 0.002 ether}("")` | Funds target; `send` back to ownerless contract fails |
| 5 | `enter()` | All gates pass → `entrant = tx.origin` |

```solidity
function attack() external payable {
    password = block.timestamp;          // Snapshot before createTrick
    IExploit(target).createTrick();      // SimpleTrick password == same timestamp
    IExploit(target).construct0r();      // Seize ownership
    IExploit(target).getAllowance(password); // Gate Two: allowEntrance = true
    (bool ok, ) = payable(target).call{value: 0.002 ether}(""); // Fund target
    require(ok);
    IExploit(target).enter();            // Gate Three passes — send() fails back to us
}
```

## Real-World Reference

The typo-constructor pattern is a documented anti-pattern from the pre-0.5.0 Solidity era, when constructors were named after their contract. Several early tokens shipped with functions named identically to the contract (but with wrong casing or a typo), leaving ownership permanently open. The `block.timestamp` entropy weakness mirrors the Theran/PRNG exploitation pattern seen in on-chain lottery contracts where miners could influence or predict outcomes.
