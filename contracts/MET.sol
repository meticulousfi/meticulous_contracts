// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MetToken is ERC20, Ownable {
    constructor() ERC20("MET", "MET") Ownable(msg.sender) {
        _mint(msg.sender, 100 ether);
    }

    function mint(address _minter) public onlyOwner {
        uint256 amount = 10000000 ether;
        _mint(_minter, amount);
    }

    function burn(address _burner, uint256 _amount) public onlyOwner {
        _burn(_burner, _amount);
    }
}
