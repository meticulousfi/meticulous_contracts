// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

//  _____ ______   _______  _________  ___  ________  ___  ___  ___       ________  ___  ___  ________      
// |\   _ \  _   \|\  ___ \|\___   ___\\  \|\   ____\|\  \|\  \|\  \     |\   __  \|\  \|\  \|\   ____\     
// \ \  \\\__\ \  \ \   __/\|___ \  \_\ \  \ \  \___|\ \  \\\  \ \  \    \ \  \|\  \ \  \\\  \ \  \___|_    
//  \ \  \\|__| \  \ \  \_|/__  \ \  \ \ \  \ \  \    \ \  \\\  \ \  \    \ \  \\\  \ \  \\\  \ \_____  \   
//   \ \  \    \ \  \ \  \_|\ \  \ \  \ \ \  \ \  \____\ \  \\\  \ \  \____\ \  \\\  \ \  \\\  \|____|\  \  
//    \ \__\    \ \__\ \_______\  \ \__\ \ \__\ \_______\ \_______\ \_______\ \_______\ \_______\____\_\  \ 
//     \|__|     \|__|\|_______|   \|__|  \|__|\|_______|\|_______|\|_______|\|_______|\|_______|\_________\
//   

import "@openzeppelin/contracts/governance/Governor.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorSettings.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorCountingSimple.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorVotes.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorVotesQuorumFraction.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorTimelockCompound.sol";

contract Governor is Governor, GovernorSettings, GovernorCountingSimple, GovernorVotes, GovernorVotesQuorumFraction, GovernorTimelockCompound {
    constructor(IVotes _token, ICompoundTimelock _timelock)
        Governor("Hamilton")
        GovernorSettings(50400 /* 7 day */, 50400 /* 1 week */, 100000000e18) // 100M tokens for proposal
        GovernorVotes(_token)
        GovernorVotesQuorumFraction(10)
        GovernorTimelockCompound(_timelock)
    {}

    // The following functions are overrides required by Solidity.

    function votingDelay()
        public
        view
        override(IGovernor, GovernorSettings)
        returns (uint256)
    {
        return super.votingDelay();
    }

    function votingPeriod()
        public
        view
        override(IGovernor, GovernorSettings)
        returns (uint256)
    {
        return super.votingPeriod();
    }

    function quorum(uint256 blockNumber)
        public
        view
        override(IGovernor, GovernorVotesQuorumFraction)
        returns (uint256)
    {
        return super.quorum(blockNumber);
    }

    function state(uint256 proposalId)
        public
        view
        override(Governor, GovernorTimelockCompound)
        returns (ProposalState)
    {
        return super.state(proposalId);
    }

    function propose(address[] memory targets, uint256[] memory values, bytes[] memory calldatas, string memory description)
        public
        override(Governor, IGovernor)
        returns (uint256)
    {
        return super.propose(targets, values, calldatas, description);
    }

    function proposalThreshold()
        public
        view
        override(Governor, GovernorSettings)
        returns (uint256)
    {
        return super.proposalThreshold();
    }

    function _execute(uint256 proposalId, address[] memory targets, uint256[] memory values, bytes[] memory calldatas, bytes32 descriptionHash)
        internal
        override(Governor, GovernorTimelockCompound)
    {
        super._execute(proposalId, targets, values, calldatas, descriptionHash);
    }

    function _cancel(address[] memory targets, uint256[] memory values, bytes[] memory calldatas, bytes32 descriptionHash)
        internal
        override(Governor, GovernorTimelockCompound)
        returns (uint256)
    {
        return super._cancel(targets, values, calldatas, descriptionHash);
    }

    function _executor()
        internal
        view
        override(Governor, GovernorTimelockCompound)
        returns (address)
    {
        return super._executor();
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(Governor, GovernorTimelockCompound)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
