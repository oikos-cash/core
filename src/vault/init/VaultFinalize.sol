// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IDiamondCut } from "../../interfaces/IDiamondCut.sol";
import { IFacet } from "../../interfaces/IFacet.sol";
import "../../errors/Errors.sol";

interface IDiamondInterface {
    function initialize() external;
    function transferOwnership(address) external;
}

/**
 * @title VaultFinalize
 * @notice A contract for finalizing the upgrade of a Diamond proxy vault.
 * @dev This contract is responsible for adding new facets to the Diamond proxy and transferring ownership to the final authority.
 *      Uses pre-deployed facet addresses to stay under 24KB contract size limit.
 */
contract VaultFinalize  {
    // State variables
    address private owner; // The address of the contract owner.
    address private finalAuthority; // The address of the final authority.
    address private upgradePreviousStep; // The address of the previous upgrade step contract.

    // Pre-deployed facet addresses (set via init)
    address private facetShift;
    address private facetLending;
    address private facetLiquidation;
    
    /**
     * @notice Constructor to initialize the VaultFinalize contract.
     * @param _owner The address of the contract owner.
     */
    constructor(address _owner) {
        owner = _owner;
    }

    /**
     * @notice Initializes the contract with the final authority, previous step, and pre-deployed facets.
     * @param _finalAuthority The address of the final authority.
     * @param _upgradePreviousStep The address of the previous upgrade step contract.
     * @param _facetShift Pre-deployed ExtVaultShift address.
     * @param _facetLending Pre-deployed ExtVaultLending address.
     * @param _facetLiquidation Pre-deployed ExtVaultLiquidation address.
     */
    function init(
        address _finalAuthority,
        address _upgradePreviousStep,
        address _facetShift,
        address _facetLending,
        address _facetLiquidation
    ) onlyOwner public {
        if (_upgradePreviousStep == address(0)) revert InvalidAddress();
        if (_facetShift == address(0)) revert InvalidAddress();
        if (_facetLending == address(0)) revert InvalidAddress();
        if (_facetLiquidation == address(0)) revert InvalidAddress();

        finalAuthority = _finalAuthority;
        upgradePreviousStep = _upgradePreviousStep;
        facetShift = _facetShift;
        facetLending = _facetLending;
        facetLiquidation = _facetLiquidation;
    }


    /**
     * @notice Finalizes the upgrade of the Diamond proxy by adding new facets and transferring ownership.
     * @param diamond The address of the Diamond proxy contract.
     * @dev Uses pre-deployed facet addresses (set via init) to stay under 24KB limit.
     */
    function doUpgradeFinalize(address diamond) public authorized {
        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](3);

        cuts[0] = IDiamondCut.FacetCut({
            facetAddress: facetShift,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: IFacet(facetShift).getFunctionSelectors()
        });

        cuts[1] = IDiamondCut.FacetCut({
            facetAddress: facetLending,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: IFacet(facetLending).getFunctionSelectors()
        });

        cuts[2] = IDiamondCut.FacetCut({
            facetAddress: facetLiquidation,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: IFacet(facetLiquidation).getFunctionSelectors()
        });

        IDiamondCut(diamond).diamondCut(cuts, address(0), "");
        IDiamondInterface(diamond).transferOwnership(finalAuthority);
    }  

    /**
     * @notice Modifier to restrict access to the contract owner.
     */
    modifier onlyOwner() {
        if (msg.sender != owner) revert OnlyOwner();
        _;
    }

    /**
     * @notice Modifier to restrict access to the previous upgrade step contract.
     */
    modifier authorized() {
        if (msg.sender != upgradePreviousStep) revert NotAuthorized();
        _;
    }
}