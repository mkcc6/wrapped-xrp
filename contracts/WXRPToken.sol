// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { ERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import { AccessControlUpgradeable } from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import { IWXRPToken } from "./interfaces/IWXRPToken.sol";

/**
 * @title WXRPToken
 * @notice Wrapped XRP upgradeable ERC20 token.
 * @dev Implements role-based access control for minting, burning, pausing, and blacklisting.
 *      Includes blacklist functionality and an emergency pause mechanism.
 */
contract WXRPToken is IWXRPToken, ERC20Upgradeable, AccessControlUpgradeable, PausableUpgradeable {
    bytes32 public constant BLACKLISTER_ROLE = keccak256("BLACKLISTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    mapping(address => bool) public isBlacklisted;

    /// @dev Not using ERC-7201 as this contract is not meant to be inherited.
    uint256[49] private __gap;

    // ============ Initialization ============

    function initialize(address _admin) public virtual initializer {
        if (_admin == address(0)) revert ZeroAddress();
        __ERC20_init("Wrapped XRP", "wXRP");
        __AccessControl_init();
        __Pausable_init();
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
    }

    constructor() {
        _disableInitializers();
    }

    // ============ Blacklisting ============

    /**
     * @notice Modifier to check that an address is not blacklisted.
     * @dev Reverts if the address is blacklisted.
     * @param _address Address to check
     */
    modifier notBlacklisted(address _address) {
        if (isBlacklisted[_address]) {
            revert Blacklisted(_address);
        }
        _;
    }

    /**
     * @notice Adds an address to the blacklist.
     * @dev Only callable by accounts with `BLACKLISTER_ROLE`. Address must not already be blacklisted.
     * @param _address Address to add to the blacklist
     */
    function addToBlacklist(address _address) public virtual onlyRole(BLACKLISTER_ROLE) notBlacklisted(_address) {
        isBlacklisted[_address] = true;
        emit AddedToBlacklist(_address);
    }

    /**
     * @notice Removes an address from the blacklist, restoring token operation capabilities.
     * @dev Only callable by accounts with `BLACKLISTER_ROLE`. Address must currently be blacklisted.
     * @param _address Address to remove from the blacklist
     */
    function removeFromBlacklist(address _address) public virtual onlyRole(BLACKLISTER_ROLE) {
        if (!isBlacklisted[_address]) {
            revert NotBlacklisted(_address);
        }
        isBlacklisted[_address] = false;
        emit RemovedFromBlacklist(_address);
    }

    // ============ Pausing ============

    /**
     * @notice Pauses all token transfers and burning.
     * @dev Only callable by accounts with `PAUSER_ROLE` when contract is not already paused.
     *      It does not pause minting.
     */
    function pause() public virtual onlyRole(PAUSER_ROLE) whenNotPaused {
        _pause();
    }

    /**
     * @notice Unpauses the contract, resuming normal token operations.
     * @dev Only callable by accounts with `PAUSER_ROLE` when contract is paused.
     */
    function unpause() public virtual onlyRole(PAUSER_ROLE) whenPaused {
        _unpause();
    }

    // ============ Minting and Burning ============

    /**
     * @notice Mints tokens to address.
     * @dev Only callable by accounts with `MINTER_ROLE`.
     *      It does not revert if the recipient is blacklisted or the contract is paused,
     *      as funds cannot be debited in that state.
     * @param _to Address to mint tokens to
     * @param _amount Amount of tokens to mint
     * @return success Always returns true
     */
    function mint(address _to, uint256 _amount) public virtual onlyRole(MINTER_ROLE) returns (bool success) {
        _mint(_to, _amount);
        emit Minted(msg.sender, _to, _amount);
        return true;
    }

    /**
     * @notice Burns tokens from address without approval.
     * @dev Only callable by accounts with `BURNER_ROLE`.
     *      It reverts if the address is blacklisted or the contract is paused.
     * @param _from Address to burn tokens from
     * @param _amount Amount of tokens to burn
     * @return success Always returns true
     */
    function burn(
        address _from,
        uint256 _amount
    ) public virtual onlyRole(BURNER_ROLE) notBlacklisted(_from) whenNotPaused returns (bool success) {
        _burn(_from, _amount);
        emit Burned(msg.sender, _from, _amount);
        return true;
    }

    // ============ ERC20 Overrides ============

    /// @dev Overrides the default 18 decimals to use 6.
    function decimals() public view virtual override returns (uint8) {
        return 6;
    }

    /// @dev Overrides ERC20 transfer to add blacklist and pause protections.
    function transfer(
        address _to,
        uint256 _amount
    ) public virtual override notBlacklisted(msg.sender) notBlacklisted(_to) whenNotPaused returns (bool success) {
        return super.transfer(_to, _amount);
    }

    /// @dev Overrides ERC20 transfer to add blacklist and pause protections.
    function transferFrom(
        address _from,
        address _to,
        uint256 _amount
    )
        public
        virtual
        override
        notBlacklisted(msg.sender)
        notBlacklisted(_from)
        notBlacklisted(_to)
        whenNotPaused
        returns (bool success)
    {
        return super.transferFrom(_from, _to, _amount);
    }
}
