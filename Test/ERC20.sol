// SPDX-License-Identifier: MIT
pragma solidity ^0.8;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract SimpleERC20 is ERC20 {
    constructor(uint256 _initialSupply)  ERC20("Simple", "SIM") {
        _mint(msg.sender, _initialSupply);
    }
}
