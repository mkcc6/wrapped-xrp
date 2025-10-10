// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

/**
 * @title IWXRPToken
 * @notice Interface for Wrapped XRP upgradeable ERC20 token.
 */
interface IWXRPToken {
    // ============ Events ============

    /// @notice Emitted when an address is added to the blacklist.
    /// @param _address Address that was blacklisted
    event AddedToBlacklist(address indexed _address);

    /// @notice Emitted when an address is removed from the blacklist.
    /// @param _address Address that was removed from the blacklist
    event RemovedFromBlacklist(address indexed _address);

    /**
     * @notice Emitted when tokens are minted to an address.
     * @param _minter Address that executed the minting operation
     * @param _to Address that received the minted tokens
     * @param _amount Amount of tokens that were minted
     */
    event Minted(address indexed _minter, address indexed _to, uint256 _amount);

    /**
     * @notice Emitted when tokens are burned from an address.
     * @param _burner Address that executed the burning operation
     * @param _from Address that sent the tokens to be burned
     * @param _amount Amount of tokens that were burned
     */
    event Burned(address indexed _burner, address indexed _from, uint256 _amount);

    // ============ Errors ============

    /// @notice Thrown when attempting to interact with a zero address.
    error ZeroAddress();

    /// @notice Thrown when attempting to interact with a blacklisted address.
    /// @param _address Blacklisted address that was involved in the operation
    error Blacklisted(address _address);

    /// @notice Thrown when attempting to remove an address from blacklist that isn't blacklisted.
    /// @param _address Address that is not currently blacklisted
    error NotBlacklisted(address _address);

    // ============ Blacklisting ============

    /**
     * @notice Adds an address to the blacklist.
     * @dev Only callable by accounts with `BLACKLISTER_ROLE`. Address must not already be blacklisted.
     * @param _address Address to add to the blacklist
     */
    function addToBlacklist(address _address) external;

    /**
     * @notice Removes an address from the blacklist, restoring token operation capabilities.
     * @dev Only callable by accounts with `BLACKLISTER_ROLE`. Address must currently be blacklisted.
     * @param _address Address to remove from the blacklist
     */
    function removeFromBlacklist(address _address) external;

    /**
     * @notice Returns whether an address is blacklisted.
     * @param _address Address to check blacklist status for
     * @return True if the address is blacklisted, false otherwise
     */
    function isBlacklisted(address _address) external view returns (bool);

    // ============ Pausing ============

    /**
     * @notice Pauses all token transfers and burning.
     * @dev Only callable by accounts with `PAUSER_ROLE` when contract is not already paused.
     *      It does not pause minting.
     */
    function pause() external;

    /**
     * @notice Unpauses the contract, resuming normal token operations.
     * @dev Only callable by accounts with `PAUSER_ROLE` when contract is paused.
     */
    function unpause() external;

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
    function mint(address _to, uint256 _amount) external returns (bool success);

    /**
     * @notice Burns tokens from address without approval.
     * @dev Only callable by accounts with `BURNER_ROLE`.
     *      It reverts if the address is blacklisted or the contract is paused.
     * @param _from Address to burn tokens from
     * @param _amount Amount of tokens to burn
     * @return success Always returns true
     */
    function burn(address _from, uint256 _amount) external returns (bool success);
}
