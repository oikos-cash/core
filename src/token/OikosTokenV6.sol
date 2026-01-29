// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {IAddressResolver} from "../interfaces/IAddressResolver.sol";
import {Utils} from "../libraries/Utils.sol";
import {OikosDividends} from "../controllers/OikosDividends.sol";

/**
 * @title OikosTokenV6
 * @notice Oikos token contract V6
 * @dev Removes syncReserveIndex and recoverTokens functions from V5
 */
contract OikosTokenV6 is Initializable, ERC20Upgradeable, OwnableUpgradeable, UUPSUpgradeable {

    // State variables - MUST match previous storage layout exactly
    IAddressResolver public resolver;
    uint256 public maxTotalSupply;
    OikosDividends public dividendsManager;
    address public manager;
    mapping(address => bool) public isBackLogAddress;

    // Custom errors
    error Unauthorized();
    error OnlyFactory();
    error CannotInitializeLogicContract();
    error MaxSupplyReached();
    error InvalidResolver();
    error RecoveryFailed();

    constructor() {
        _disableInitializers();
    }

    function initializeV6() external reinitializer(6) {
        // No new state to initialize
    }

    // ============ Existing functions ============

    function mint(address _recipient, uint256 _amount) public onlyFactory {
        _mint(_recipient, _amount);
    }

    function burn(address account, uint256 amount) public onlyFactory {
        _burn(account, amount);
    }

    function _update(
        address from,
        address to,
        uint256 value
    ) internal override(ERC20Upgradeable) {
        if (address(dividendsManager) != address(0)) {
            dividendsManager.onSharesTransferHook(from, to);
        }
        super._update(from, to, value);
    }

    function setDividendsManager(OikosDividends _manager) external onlyAuthorized {
        dividendsManager = _manager;
    }

    function setResolver(address _resolver) external onlyOwner {
        if (_resolver == address(0)) revert InvalidResolver();
        resolver = IAddressResolver(_resolver);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    function version() public pure returns (string memory) {
        return "6";
    }

    function proxiableUUID() public pure override returns (bytes32) {
        bytes32 hash = keccak256("eip1967.proxy.implementation");
        bytes32 slot = bytes32(uint256(hash) - 1);
        return slot;
    }

    function setOwner(address _owner) external onlyOwner {
        super.transferOwnership(_owner);
    }

    function renounceOwnership() public override onlyOwner {
        super.renounceOwnership();
    }

    function oikosFactory() public view returns (address) {
        return resolver.requireAndGetAddress(
            Utils.stringToBytes32("OikosFactory"),
            "no OikosFactory"
        );
    }

    modifier onlyFactory() {
        if (msg.sender != oikosFactory()) revert OnlyFactory();
        _;
    }

    modifier onlyAuthorized() {
        if (msg.sender != manager && msg.sender != owner()) revert Unauthorized();
        _;
    }
}
