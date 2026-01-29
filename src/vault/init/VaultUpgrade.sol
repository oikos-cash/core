// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { StakingVault } from "../StakingVault.sol";
import { AuxVault } from "../AuxVault.sol";

import { LendingVault } from "../LendingVault.sol";
import { LiquidationVault } from "../LiquidationVault.sol";
import { LendingOpsVault } from "../LendingOpsVault.sol";
import { IDiamondCut } from "../../interfaces/IDiamondCut.sol";
import { IFacet } from "../../interfaces/IFacet.sol";
import { Utils } from "../../libraries/Utils.sol";
import "../../errors/Errors.sol";

/**
 * @title IVaultUpgrader
 * @notice Interface for the VaultUpgrader contract.
 */
interface IVaultUpgrader {
    function doUpgradeStart(address diamond, address _vaultUpgradeFinalize) external;
    function doUpgradeStep1(address diamond) external;
    function doUpgradeStep2(address diamond) external;
    function doUpgradeStep3(address diamond) external;
    function doUpgradeStep4(address diamond) external;
    function doUpgradeFinalize(address diamond) external;
}

/**
 * @title IDiamondInterface
 * @notice Interface for the Diamond proxy contract.
 */
interface IDiamondInterface {
    function initialize() external;
    function transferOwnership(address) external;
}

/**
 * @title VaultUpgrade
 * @notice A contract for starting the upgrade process of a Diamond proxy vault.
 * @dev This contract is responsible for adding the ExtVault facets and initiating the upgrade process.
 *      Uses pre-deployed facet addresses to stay under 24KB contract size limit.
 */
contract VaultUpgrade {
    address private owner; // The address of the contract owner.
    address private factory; // The address of the factory contract.
    address private upgradeStep1; // The address of the first upgrade step contract.
    address private upgradeFinalize; // The address of the final upgrade step contract.

    // Pre-deployed facet addresses
    address private immutable facetShift;
    address private immutable facetLending;
    address private immutable facetLiquidation;

    /**
     * @notice Constructor to initialize the VaultUpgrade contract.
     * @param _owner The address of the contract owner.
     * @param _factory The address of the factory contract.
     * @param _facetShift Pre-deployed ExtVaultShift address.
     * @param _facetLending Pre-deployed ExtVaultLending address.
     * @param _facetLiquidation Pre-deployed ExtVaultLiquidation address.
     */
    constructor(
        address _owner,
        address _factory,
        address _facetShift,
        address _facetLending,
        address _facetLiquidation
    ) {
        if (_facetShift == address(0)) revert InvalidAddress();
        if (_facetLending == address(0)) revert InvalidAddress();
        if (_facetLiquidation == address(0)) revert InvalidAddress();

        owner = _owner;
        factory = _factory;
        facetShift = _facetShift;
        facetLending = _facetLending;
        facetLiquidation = _facetLiquidation;
    }

    /**
     * @notice Starts the upgrade process by adding the ExtVault facets and initiating the next upgrade step.
     * @param diamond The address of the Diamond proxy contract.
     * @dev Uses pre-deployed facet addresses (set in constructor) to stay under 24KB limit.
     */
    function doUpgradeStart(address diamond) public onlyFactory {
        if (diamond == address(0)) revert InvalidAddress();

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
        IDiamondInterface(diamond).transferOwnership(factory);
    }     

    /**
     * @notice Modifier to restrict access to the contract owner.
     */
    modifier onlyOwner() {
        if (msg.sender != owner) {
            revert OnlyOwner();
        }
        _;
    }

    /**
     * @notice Modifier to restrict access to the factory contract.
     */
    modifier onlyFactory() {
        if (msg.sender != factory) {
            revert OnlyFactory();
        }
        _;
    }
}

/**
 * @title VaultUpgradeStep1
 * @notice A contract for the first step of the upgrade process of a Diamond proxy vault.
 * @dev This contract is responsible for adding the StakingVault facet and initiating the next upgrade step.
 */
contract VaultUpgradeStep1  {
    address private owner; // The address of the contract owner.
    address private upgradePreviousStep; // The address of the previous upgrade step contract.
    address private upgradeNextStep; // The address of the next upgrade step contract.
    address private factory; // The address of the factory contract.

    /**
     * @notice Constructor to initialize the VaultUpgradeStep1 contract.
     * @param _owner The address of the contract owner.
     */
    constructor(address _owner, address _factory) {
        owner = _owner;
        factory = _factory;
    }

    /**
     * @notice Executes the first step of the upgrade process by adding the StakingVault facet and initiating the next upgrade step.
     * @param diamond The address of the Diamond proxy contract.
     */
    function doUpgradeStart(address diamond) public onlyFactory {
 
        address[] memory newFacets = new address[](1);
        IDiamondCut.FacetCutAction[] memory actions = new IDiamondCut.FacetCutAction[](1);
        bytes4[][] memory functionSelectors = new bytes4[][](1);

        newFacets[0] = address(new StakingVault());
        actions[0] = IDiamondCut.FacetCutAction.Add;
        functionSelectors[0] = IFacet(newFacets[0]).getFunctionSelectors();

        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](newFacets.length);
        for (uint256 i = 0; i < newFacets.length; i++) {
            cuts[i] = IDiamondCut.FacetCut({
                facetAddress: newFacets[i],
                action: actions[i],
                functionSelectors: functionSelectors[i]
            });
        }

        IDiamondCut(diamond).diamondCut(cuts, address(0), "");
        IDiamondInterface(diamond).transferOwnership(factory);
    }  

    /**
     * @notice Modifier to restrict access to the factory contract.
     */
    modifier onlyFactory() {
        if (msg.sender != factory) {
            revert OnlyFactory();
        }
        _;
    }
}

/**
 * @title VaultUpgradeStep2
 * @notice A contract for the second step of the upgrade process of a Diamond proxy vault.
 * @dev This contract is responsible for adding the LendingVault facet and initiating the final upgrade step.
 */
contract VaultUpgradeStep2  {
    address private owner; // The address of the contract owner.
    address private upgradePreviousStep; // The address of the previous upgrade step contract.
    address private upgradeNextStep; // The address of the next upgrade step contract.
    address private factory; // The address of the factory contract.
    
    /**
     * @notice Constructor to initialize the VaultUpgradeStep1 contract.
     * @param _owner The address of the contract owner.
     */
    constructor(address _owner, address _factory) {
        owner = _owner;
        factory = _factory;
    }

    /**
     * @notice Executes the second step of the upgrade process by adding the LendingVault facet and initiating the final upgrade step.
     * @param diamond The address of the Diamond proxy contract.
     */
    function doUpgradeStart(address diamond) public onlyFactory()  {
 
        address[] memory newFacets = new address[](1);
        IDiamondCut.FacetCutAction[] memory actions = new IDiamondCut.FacetCutAction[](1);
        bytes4[][] memory functionSelectors = new bytes4[][](1);

        newFacets[0] = address(new LendingVault());
        actions[0] = IDiamondCut.FacetCutAction.Add;
        functionSelectors[0] = IFacet(newFacets[0]).getFunctionSelectors();

        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](newFacets.length);
        for (uint256 i = 0; i < newFacets.length; i++) {
            cuts[i] = IDiamondCut.FacetCut({
                facetAddress: newFacets[i],
                action: actions[i],
                functionSelectors: functionSelectors[i]
            });
        }

        IDiamondCut(diamond).diamondCut(cuts, address(0), "");
        IDiamondInterface(diamond).transferOwnership(factory);
    }  

    /**
     * @notice Modifier to restrict access to the factory contract.
     */
    modifier onlyFactory() {
        if (msg.sender != factory) {
            revert OnlyFactory();
        }
        _;
    }

    /**
     * @notice Modifier to restrict access to the contract owner.
     */
    modifier onlyOwner() {
        if (msg.sender != owner) {
            revert OnlyOwner();
        }
        _;
    }

    /**
     * @notice Modifier to restrict access to the previous upgrade step contract.
     */
    modifier authorized() {
        if (msg.sender != upgradePreviousStep) {
            revert NotAuthorized();
        }
        _;
    }
}

/**
 * @title VaultUpgradeStep3
 * @notice A contract for the second step of the upgrade process of a Diamond proxy vault.
 * @dev This contract is responsible for adding the LendingVault facet and initiating the final upgrade step.
 */
contract VaultUpgradeStep3  {
    address private owner; // The address of the contract owner.
    address private upgradePreviousStep; // The address of the previous upgrade step contract.
    address private upgradeNextStep; // The address of the next upgrade step contract.
    address private factory; // The address of the factory contract.
    
    /**
     * @notice Constructor to initialize the VaultUpgradeStep2 contract.
     * @param _owner The address of the contract owner.
     */
    constructor(address _owner, address _factory) {
        owner = _owner;
        factory = _factory;
    }


    /**
     * @notice Executes the second step of the upgrade process by adding the LendingVault facet and initiating the final upgrade step.
     * @param diamond The address of the Diamond proxy contract.
     */
    function doUpgradeStart(address diamond) public onlyFactory  {
 
        address[] memory newFacets = new address[](1);
        IDiamondCut.FacetCutAction[] memory actions = new IDiamondCut.FacetCutAction[](1);
        bytes4[][] memory functionSelectors = new bytes4[][](1);

        newFacets[0] = address(new LiquidationVault());
        actions[0] = IDiamondCut.FacetCutAction.Add;
        functionSelectors[0] = IFacet(newFacets[0]).getFunctionSelectors();

        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](newFacets.length);
        for (uint256 i = 0; i < newFacets.length; i++) {
            cuts[i] = IDiamondCut.FacetCut({
                facetAddress: newFacets[i],
                action: actions[i],
                functionSelectors: functionSelectors[i]
            });
        }

        IDiamondCut(diamond).diamondCut(cuts, address(0), "");
        IDiamondInterface(diamond).transferOwnership(factory);

    }  
    
    /**
     * @notice Modifier to restrict access to the factory contract.
     */
    modifier onlyFactory() {
        if (msg.sender != factory) {
            revert OnlyFactory();
        }
        _;
    }

    /**
     * @notice Modifier to restrict access to the contract owner.
     */
    modifier onlyOwner() {
        if (msg.sender != owner) {
            revert OnlyOwner();
        }
        _;
    }

    /**
     * @notice Modifier to restrict access to the previous upgrade step contract.
     */
    modifier authorized() {
        if (msg.sender != upgradePreviousStep) {
            revert NotAuthorized();
        }
        _;
    }
}

/**
 * @title VaultUpgradeStep4
 * @notice A contract for the second step of the upgrade process of a Diamond proxy vault.
 * @dev This contract is responsible for adding the LendingVault facet and initiating the final upgrade step.
 */
contract VaultUpgradeStep4  {
    address private owner; // The address of the contract owner.
    address private upgradePreviousStep; // The address of the previous upgrade step contract.
    address private upgradeNextStep; // The address of the next upgrade step contract.
    address private factory; // The address of the factory contract.
    
    /**
     * @notice Constructor to initialize the VaultUpgradeStep2 contract.
     * @param _owner The address of the contract owner.
     */
    constructor(address _owner, address _factory) {
        owner = _owner;
        factory = _factory;
    }


    /**
     * @notice Executes the second step of the upgrade process by adding the LendingVault facet and initiating the final upgrade step.
     * @param diamond The address of the Diamond proxy contract.
     */
    function doUpgradeStart(address diamond) public onlyFactory  {
 
        address[] memory newFacets = new address[](1);
        IDiamondCut.FacetCutAction[] memory actions = new IDiamondCut.FacetCutAction[](1);
        bytes4[][] memory functionSelectors = new bytes4[][](1);

        newFacets[0] = address(new LendingOpsVault());
        actions[0] = IDiamondCut.FacetCutAction.Add;
        functionSelectors[0] = IFacet(newFacets[0]).getFunctionSelectors();

        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](newFacets.length);
        for (uint256 i = 0; i < newFacets.length; i++) {
            cuts[i] = IDiamondCut.FacetCut({
                facetAddress: newFacets[i],
                action: actions[i],
                functionSelectors: functionSelectors[i]
            });
        }

        IDiamondCut(diamond).diamondCut(cuts, address(0), "");
        IDiamondInterface(diamond).transferOwnership(factory);
    }  

    modifier onlyFactory() {
        if (msg.sender != factory) {
            revert OnlyFactory();
        }
        _;
    }

    /**
     * @notice Modifier to restrict access to the contract owner.
     */
    modifier onlyOwner() {
        if (msg.sender != owner) {
            revert OnlyOwner();
        }
        _;
    }

    /**
     * @notice Modifier to restrict access to the previous upgrade step contract.
     */
    modifier authorized() {
        if (msg.sender != upgradePreviousStep) {
            revert NotAuthorized();
        }
        _;
    }
}

/**
 * @title VaultUpgradeStep5
 * @notice A contract for the second step of the upgrade process of a Diamond proxy vault.
 * @dev This contract is responsible for adding the LendingVault facet and initiating the final upgrade step.
 */
contract VaultUpgradeStep5  {
    address private owner; // The address of the contract owner.
    address private factory; // The address of the factory contract.
    
    /**
     * @notice Constructor to initialize the VaultUpgradeStep2 contract.
     * @param _owner The address of the contract owner.
     */
    constructor(address _owner, address _factory) {
        owner = _owner;
        factory = _factory;
    }

    /**
     * @notice Executes the second step of the upgrade process by adding the LendingVault facet and initiating the final upgrade step.
     * @param diamond The address of the Diamond proxy contract.
     */
    function doUpgradeStart(address diamond) public onlyFactory  {
 
        address[] memory newFacets = new address[](1);
        IDiamondCut.FacetCutAction[] memory actions = new IDiamondCut.FacetCutAction[](1);
        bytes4[][] memory functionSelectors = new bytes4[][](1);

        newFacets[0] = address(new AuxVault());
        actions[0] = IDiamondCut.FacetCutAction.Add;
        functionSelectors[0] = IFacet(newFacets[0]).getFunctionSelectors();

        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](newFacets.length);
        for (uint256 i = 0; i < newFacets.length; i++) {
            cuts[i] = IDiamondCut.FacetCut({
                facetAddress: newFacets[i],
                action: actions[i],
                functionSelectors: functionSelectors[i]
            });
        }

        IDiamondCut(diamond).diamondCut(cuts, address(0), "");
        IDiamondInterface(diamond).transferOwnership(factory);
    }  

    modifier onlyFactory() {
        if (msg.sender != factory) {
            revert OnlyFactory();
        }
        _;
    }

}