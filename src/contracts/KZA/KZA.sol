// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {ERC20, ERC20Permit} from "@openzeppelin/token/ERC20/extensions/draft-ERC20Permit.sol";

// | |/ /_ _| \ | |__  /  / \   
// | ' / | ||  \| | / /  / _ \  
// | . \ | || |\  |/ /_ / ___ \ 
// |_|\_\___|_| \_/____/_/   \_\

/// @notice KZA - Kinza protocol governance token
/// @title KZA
/// @notice  Minimal implmentation of a governance token
contract KZA is ERC20("KINZA", "KZA"), ERC20Permit("KINZA") {

    /*//////////////////////////////////////////////////////////////
                        CONSTANTS & IMMUTABLES
    //////////////////////////////////////////////////////////////*/

    uint private constant governanceDelay = 3 days;
    uint private constant MAX_SUPPLY = 100_000_000 * 10 ** 18;

    /*//////////////////////////////////////////////////////////////
                            STORAGE VARIABLES 
    //////////////////////////////////////////////////////////////*/

    bool public initialMinted;
    uint public newGovernanceProposedTime;

    address public minter;
    address public governance;
    address public newGovernance;

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event NewGovernance(
        address oldGovernance, 
        address newGovernance
    );

    event NewGovernanceProposal(address newGovernance);

    event NewBribeMinter(address newMinter);

    /*//////////////////////////////////////////////////////////////
                                MODIFIER
    //////////////////////////////////////////////////////////////*/
    modifier onlyGov() {
      require(msg.sender == governance, "only governance");
      _;
    }

    modifier onlyNewGov() {
      require(msg.sender == newGovernance, "only new governance");
      _;
    }

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor(address _governance) {
        governance = _governance;
    }

    /// @notice governance can use this to propose/cancel newGovernance.
    /// @param _newGovernace new governance
    function proposeNewGovernance(address _newGovernace) onlyGov external {
      newGovernanceProposedTime = block.timestamp;
      newGovernance = _newGovernace;
      emit NewGovernanceProposal(_newGovernace);
    }

    /// @notice newGovernance need to accept the governance role
    function acceptNewGovernance() onlyNewGov external {
      require(block.timestamp > governanceDelay + newGovernanceProposedTime, "pending governance delay");
      emit NewGovernance(governance, newGovernance);
      governance = newGovernance;
      newGovernance = address(0);
    }

    /// @notice governance can use this to update bribe minter contracts
    /// @param _minter new minter
    function setBribeMinter(address _minter) onlyGov external {
        minter = _minter;
        emit NewBribeMinter(_minter);
    }
    
    /// @notice Initial mint: 40M for reserve, team vesting, investor, initial LP etc
    ///         60M for community incentive to be minted by BribeMinter
    /// @param _recipient the recipient, would be the vestingEscrow
    function initialMint(address _recipient) onlyGov external {
        require(!initialMinted, "initial mint is already done");
        initialMinted = true;
        _mint(_recipient, 40_000_000 * 1e18);
    }

    /// @param _account the recipient of tokens
    /// @param _amount the amount to mint
    function mint(address _account, uint _amount) external {
        require(msg.sender == minter, "onlyMinter");
        require(totalSupply() + _amount <= MAX_SUPPLY, "exceeds max supply");
        _mint(_account, _amount);
    }

    /// @param _amount the amount to burn
    function burn(uint _amount) external {
      _burn(msg.sender, _amount);
    }

}