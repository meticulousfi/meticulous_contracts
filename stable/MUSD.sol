// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

//  _____ ______   _______  _________  ___  ________  ___  ___  ___       ________  ___  ___  ________      
// |\   _ \  _   \|\  ___ \|\___   ___\\  \|\   ____\|\  \|\  \|\  \     |\   __  \|\  \|\  \|\   ____\     
// \ \  \\\__\ \  \ \   __/\|___ \  \_\ \  \ \  \___|\ \  \\\  \ \  \    \ \  \|\  \ \  \\\  \ \  \___|_    
//  \ \  \\|__| \  \ \  \_|/__  \ \  \ \ \  \ \  \    \ \  \\\  \ \  \    \ \  \\\  \ \  \\\  \ \_____  \   
//   \ \  \    \ \  \ \  \_|\ \  \ \  \ \ \  \ \  \____\ \  \\\  \ \  \____\ \  \\\  \ \  \\\  \|____|\  \  
//    \ \__\    \ \__\ \_______\  \ \__\ \ \__\ \_______\ \_______\ \_______\ \_______\ \_______\____\_\  \ 
//     \|__|     \|__|\|_______|   \|__|  \|__|\|_______|\|_______|\|_______|\|_______|\|_______|\_________\
//

import {ERC20Burnable, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract MUSD is ERC20Burnable, Ownable {

    address controller;

    error MUSD__AmountMustBeMoreThanZero();
    error MUSD__BurnAmountExceedsBalance();
    error MUSD__NotZeroAddress();

    constructor() ERC20("Meticulous USD", "MUSD") Ownable() {}


    function setController(address _controller) external onlyOwner {
      controller = _controller;
    }

    function burn(uint256 _amount) public override {
        require(msg.sender == controller, "you do not have the permission");
        uint256 balance = balanceOf(msg.sender);
        if (_amount <= 0) {
            revert MUSD__AmountMustBeMoreThanZero();
        }
        if (balance < _amount) {
            revert MUSD__BurnAmountExceedsBalance();
        }
        super.burn(_amount);
    }

    function mint(address _to, uint256 _amount) external returns (bool) {
        require(msg.sender == controller, "you do not have the permission");
        if (_to == address(0)) {
            revert MUSD__NotZeroAddress();
        }
        if (_amount <= 0) {
            revert MUSD__AmountMustBeMoreThanZero();
        }
        _mint(_to, _amount);
        return true;
    }
}
