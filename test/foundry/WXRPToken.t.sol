// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { Test, console } from "forge-std/Test.sol";

import { TransparentUpgradeableProxy, ITransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import { ERC1967Utils } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";
import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";
import { IERC20Errors } from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

import { WXRPToken } from "contracts/WXRPToken.sol";
import { IWXRPToken } from "contracts/interfaces/IWXRPToken.sol";

contract WXRPTokenV2 is WXRPToken {
    function reinitialize(address _additionalAdmin) public reinitializer(2) {
        _grantRole(DEFAULT_ADMIN_ROLE, _additionalAdmin);
    }

    function name() public pure override returns (string memory) {
        return "Upgraded";
    }

    function symbol() public pure override returns (string memory) {
        return "UPG";
    }
}

contract AtomicBurner is Ownable {
    constructor() Ownable(msg.sender) {}

    function burnBlacklisted(address _token, address _to, uint256 _amount) public onlyOwner {
        WXRPToken(_token).removeFromBlacklist(_to);
        WXRPToken(_token).burn(_to, _amount);
        WXRPToken(_token).addToBlacklist(_to);
    }

    function burnPaused(address _token, address _to, uint256 _amount) public onlyOwner {
        WXRPToken(_token).unpause();
        WXRPToken(_token).burn(_to, _amount);
        WXRPToken(_token).pause();
    }
}

contract WXRPTokenTest is Test {
    WXRPToken impl;
    WXRPToken proxy;
    ProxyAdmin proxyAdmin;

    bytes32 constant DEFAULT_ADMIN_ROLE = 0x00;
    bytes32 minterRole;
    bytes32 burnerRole;
    bytes32 blacklisterRole;
    bytes32 pauserRole;

    uint256 alicePk = 1;
    uint256 bobPk = 2;
    uint256 charliePk = 3;
    uint256 davePk = 4;
    uint256 evePk = 5;

    address alice = vm.addr(alicePk);
    address bob = vm.addr(bobPk);
    address charlie = vm.addr(charliePk);
    address dave = vm.addr(davePk);
    address eve = vm.addr(evePk);

    function _getProxyAdminAddress(address _proxy) internal view returns (address) {
        bytes32 adminSlot = vm.load(_proxy, ERC1967Utils.ADMIN_SLOT);
        return address(uint160(uint256(adminSlot)));
    }

    function _deployTUP(address _proxyAdminOwner, address _initialAdmin) internal {
        TransparentUpgradeableProxy _proxy = new TransparentUpgradeableProxy(
            address(impl),
            _proxyAdminOwner,
            abi.encodeWithSelector(WXRPToken.initialize.selector, _initialAdmin)
        );
        proxy = WXRPToken(address(_proxy));
    }

    function setUp() public {
        // Label accounts.
        vm.label(address(this), "this");
        vm.label(alice, "alice");
        vm.label(bob, "bob");
        vm.label(charlie, "charlie");
        vm.label(dave, "dave");
        vm.label(eve, "eve");

        // Deploy.
        impl = new WXRPToken();
        _deployTUP(dave, address(this));
        proxyAdmin = ProxyAdmin(_getProxyAdminAddress(address(proxy)));

        // Cache role constants.
        minterRole = proxy.MINTER_ROLE();
        burnerRole = proxy.BURNER_ROLE();
        blacklisterRole = proxy.BLACKLISTER_ROLE();
        pauserRole = proxy.PAUSER_ROLE();
    }

    // ============================================
    //                    SETUP
    // ============================================

    function test_constructor() public {
        WXRPToken newImpl = new WXRPToken();
        // Constructor should disable initializers.
        vm.expectRevert();
        newImpl.initialize(address(this));
    }

    function test_initialize_Success() public view {
        assertEq(proxy.name(), "Wrapped XRP");
        assertEq(proxy.symbol(), "wXRP");
        assertEq(proxy.decimals(), 6);
        assertEq(proxy.totalSupply(), 0);
        assertTrue(proxy.hasRole(DEFAULT_ADMIN_ROLE, address(this)));
    }

    function test_initialize_Revert_AlreadyInitialized() public {
        vm.expectRevert();
        proxy.initialize(address(this));
    }

    function test_initialize_Revert_ZeroAddress() public {
        vm.expectRevert(abi.encodeWithSelector(IWXRPToken.ZeroAddress.selector));
        new TransparentUpgradeableProxy(
            address(impl),
            dave,
            abi.encodeWithSelector(WXRPToken.initialize.selector, address(0))
        );
    }

    // ============================================
    //                  BLACKLIST
    // ============================================

    function test_addToBlacklist_Success() public {
        proxy.grantRole(blacklisterRole, alice);

        assertFalse(proxy.isBlacklisted(bob));

        vm.expectEmit(true, true, true, true, address(proxy));
        emit IWXRPToken.AddedToBlacklist(bob);

        vm.prank(alice);
        proxy.addToBlacklist(bob);

        assertTrue(proxy.isBlacklisted(bob));
    }

    function test_addToBlacklist_Success_ZeroAddress() public {
        proxy.grantRole(blacklisterRole, alice);

        vm.expectEmit(true, true, true, true, address(proxy));
        emit IWXRPToken.AddedToBlacklist(address(0));

        vm.prank(alice);
        proxy.addToBlacklist(address(0));

        assertTrue(proxy.isBlacklisted(address(0)));
    }

    function test_addToBlacklist_Revert_Unauthorized() public {
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, alice, blacklisterRole)
        );
        vm.prank(alice);
        proxy.addToBlacklist(bob);
    }

    function test_addToBlacklist_Revert_AlreadyBlacklisted() public {
        proxy.grantRole(blacklisterRole, alice);

        vm.prank(alice);
        proxy.addToBlacklist(bob);

        vm.expectRevert(abi.encodeWithSelector(IWXRPToken.Blacklisted.selector, bob));
        vm.prank(alice);
        proxy.addToBlacklist(bob);
    }

    function test_removeFromBlacklist_Success() public {
        proxy.grantRole(blacklisterRole, alice);

        vm.prank(alice);
        proxy.addToBlacklist(bob);
        assertTrue(proxy.isBlacklisted(bob));

        vm.expectEmit(true, true, true, true, address(proxy));
        emit IWXRPToken.RemovedFromBlacklist(bob);

        vm.prank(alice);
        proxy.removeFromBlacklist(bob);

        assertFalse(proxy.isBlacklisted(bob));
    }

    function test_removeFromBlacklist_Success_ZeroAddress() public {
        proxy.grantRole(blacklisterRole, alice);

        vm.prank(alice);
        proxy.addToBlacklist(address(0));

        vm.expectEmit(true, true, true, true, address(proxy));
        emit IWXRPToken.RemovedFromBlacklist(address(0));

        vm.prank(alice);
        proxy.removeFromBlacklist(address(0));

        assertFalse(proxy.isBlacklisted(address(0)));
    }

    function test_removeFromBlacklist_Revert_Unauthorized() public {
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, alice, blacklisterRole)
        );
        vm.prank(alice);
        proxy.removeFromBlacklist(bob);
    }

    function test_removeFromBlacklist_Revert_NotBlacklisted() public {
        proxy.grantRole(blacklisterRole, alice);

        vm.expectRevert(abi.encodeWithSelector(IWXRPToken.NotBlacklisted.selector, bob));
        vm.prank(alice);
        proxy.removeFromBlacklist(bob);
    }

    // ============================================
    //                    PAUSE
    // ============================================

    function test_pause_Success() public {
        proxy.grantRole(pauserRole, alice);

        assertFalse(proxy.paused());

        vm.expectEmit(true, true, true, true, address(proxy));
        emit PausableUpgradeable.Paused(alice);

        vm.prank(alice);
        proxy.pause();

        assertTrue(proxy.paused());
    }

    function test_pause_Revert_Unauthorized() public {
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, alice, pauserRole)
        );
        vm.prank(alice);
        proxy.pause();
    }

    function test_pause_Revert_AlreadyPaused() public {
        proxy.grantRole(pauserRole, alice);

        vm.prank(alice);
        proxy.pause();

        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector, address(proxy));
        vm.prank(alice);
        proxy.pause();
    }

    function test_unpause_Success() public {
        proxy.grantRole(pauserRole, alice);

        vm.prank(alice);
        proxy.pause();
        assertTrue(proxy.paused());

        vm.expectEmit(true, true, true, true, address(proxy));
        emit PausableUpgradeable.Unpaused(alice);

        vm.prank(alice);
        proxy.unpause();

        assertFalse(proxy.paused());
    }

    function test_unpause_Revert_Unauthorized() public {
        proxy.grantRole(pauserRole, alice);

        vm.prank(alice);
        proxy.pause();

        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, bob, pauserRole)
        );
        vm.prank(bob);
        proxy.unpause();
    }

    function test_unpause_Revert_NotPaused() public {
        proxy.grantRole(pauserRole, alice);

        vm.expectRevert(PausableUpgradeable.ExpectedPause.selector, address(proxy));
        vm.prank(alice);
        proxy.unpause();
    }

    // ============================================
    //                     MINT
    // ============================================

    function test_mint_Success() public {
        proxy.grantRole(minterRole, alice);

        vm.expectEmit(true, true, true, true, address(proxy));
        emit IERC20.Transfer(address(0), bob, 1000);

        vm.expectEmit(true, true, true, true, address(proxy));
        emit IWXRPToken.Minted(alice, bob, 1000);

        vm.prank(alice);
        bool success = proxy.mint(bob, 1000);

        assertTrue(success);
        assertEq(proxy.balanceOf(bob), 1000);
        assertEq(proxy.totalSupply(), 1000);
    }

    function test_mint_Success_ZeroAmount() public {
        proxy.grantRole(minterRole, alice);

        vm.expectEmit(true, true, true, true, address(proxy));
        emit IERC20.Transfer(address(0), bob, 0);

        vm.expectEmit(true, true, true, true, address(proxy));
        emit IWXRPToken.Minted(alice, bob, 0);

        vm.prank(alice);
        bool success = proxy.mint(bob, 0);

        assertTrue(success);
        assertEq(proxy.balanceOf(bob), 0);
        assertEq(proxy.totalSupply(), 0);
    }

    function test_mint_Success_Fuzz(uint256 _amount) public {
        proxy.grantRole(minterRole, alice);

        vm.expectEmit(true, true, true, true, address(proxy));
        emit IERC20.Transfer(address(0), bob, _amount);

        vm.expectEmit(true, true, true, true, address(proxy));
        emit IWXRPToken.Minted(alice, bob, _amount);

        vm.prank(alice);
        bool success = proxy.mint(bob, _amount);

        assertTrue(success);
        assertEq(proxy.balanceOf(bob), _amount);
    }

    function test_mint_Revert_Unauthorized() public {
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, alice, minterRole)
        );
        vm.prank(alice);
        proxy.mint(bob, 1000);
    }

    function test_mint_Revert_ToZeroAddress() public {
        proxy.grantRole(minterRole, alice);

        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidReceiver.selector, address(0)));
        vm.prank(alice);
        proxy.mint(address(0), 1000);
    }

    // ============================================
    //                     BURN
    // ============================================

    function test_burn_Success() public {
        proxy.grantRole(minterRole, alice);
        proxy.grantRole(burnerRole, alice);

        vm.prank(alice);
        proxy.mint(bob, 1000);

        vm.expectEmit(true, true, true, true, address(proxy));
        emit IERC20.Transfer(bob, address(0), 500);

        vm.expectEmit(true, true, true, true, address(proxy));
        emit IWXRPToken.Burned(alice, bob, 500);

        vm.prank(alice);
        bool success = proxy.burn(bob, 500);

        assertTrue(success);
        assertEq(proxy.balanceOf(bob), 500);
        assertEq(proxy.totalSupply(), 500);
    }

    function test_burn_Success_ZeroAmount() public {
        proxy.grantRole(minterRole, alice);
        proxy.grantRole(burnerRole, alice);

        vm.prank(alice);
        proxy.mint(bob, 1000);

        vm.expectEmit(true, true, true, true, address(proxy));
        emit IERC20.Transfer(bob, address(0), 0);

        vm.expectEmit(true, true, true, true, address(proxy));
        emit IWXRPToken.Burned(alice, bob, 0);

        vm.prank(alice);
        bool success = proxy.burn(bob, 0);

        assertTrue(success);
        assertEq(proxy.balanceOf(bob), 1000);
        assertEq(proxy.totalSupply(), 1000);
    }

    function test_burn_Success_AllBalance() public {
        proxy.grantRole(minterRole, alice);
        proxy.grantRole(burnerRole, alice);

        vm.prank(alice);
        proxy.mint(bob, 1000);

        vm.expectEmit(true, true, true, true, address(proxy));
        emit IERC20.Transfer(bob, address(0), 1000);

        vm.expectEmit(true, true, true, true, address(proxy));
        emit IWXRPToken.Burned(alice, bob, 1000);

        vm.prank(alice);
        bool success = proxy.burn(bob, 1000);

        assertTrue(success);
        assertEq(proxy.balanceOf(bob), 0);
        assertEq(proxy.totalSupply(), 0);
    }

    function test_burn_Success_Fuzz(uint256 _mintAmount, uint256 _burnAmount) public {
        vm.assume(_burnAmount <= _mintAmount);

        proxy.grantRole(minterRole, alice);
        proxy.grantRole(burnerRole, alice);

        vm.prank(alice);
        proxy.mint(bob, _mintAmount);

        vm.expectEmit(true, true, true, true, address(proxy));
        emit IERC20.Transfer(bob, address(0), _burnAmount);

        vm.expectEmit(true, true, true, true, address(proxy));
        emit IWXRPToken.Burned(alice, bob, _burnAmount);

        vm.prank(alice);
        bool success = proxy.burn(bob, _burnAmount);

        assertTrue(success);
        assertEq(proxy.balanceOf(bob), _mintAmount - _burnAmount);
    }

    function test_burn_Revert_Unauthorized() public {
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, alice, burnerRole)
        );
        vm.prank(alice);
        proxy.burn(bob, 1000);
    }

    function test_burn_Revert_BlacklistedFrom() public {
        proxy.grantRole(minterRole, alice);
        proxy.grantRole(burnerRole, alice);
        proxy.grantRole(blacklisterRole, alice);

        vm.prank(alice);
        proxy.mint(bob, 1000);

        vm.prank(alice);
        proxy.addToBlacklist(bob);

        vm.expectRevert(abi.encodeWithSelector(IWXRPToken.Blacklisted.selector, bob));
        vm.prank(alice);
        proxy.burn(bob, 100);
    }

    function test_burn_Revert_WhenPaused() public {
        proxy.grantRole(minterRole, alice);
        proxy.grantRole(burnerRole, alice);
        proxy.grantRole(pauserRole, alice);

        vm.prank(alice);
        proxy.mint(bob, 1000);

        vm.prank(alice);
        proxy.pause();

        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector, address(proxy));
        vm.prank(alice);
        proxy.burn(bob, 100);
    }

    function test_burn_Revert_InsufficientBalance() public {
        proxy.grantRole(minterRole, alice);
        proxy.grantRole(burnerRole, alice);

        vm.prank(alice);
        proxy.mint(bob, 500);

        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, bob, 500, 1000));
        vm.prank(alice);
        proxy.burn(bob, 1000);
    }

    function test_burn_Revert_FromZeroAddress() public {
        proxy.grantRole(burnerRole, alice);

        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidSender.selector, address(0)));
        vm.prank(alice);
        proxy.burn(address(0), 1000);
    }

    // ============================================
    //                   TRANSFER
    // ============================================

    function test_transfer_Success() public {
        proxy.grantRole(minterRole, alice);
        vm.prank(alice);
        proxy.mint(bob, 1000);

        vm.expectEmit(true, true, true, true, address(proxy));
        emit IERC20.Transfer(bob, charlie, 500);

        vm.prank(bob);
        bool success = proxy.transfer(charlie, 500);

        assertTrue(success);
        assertEq(proxy.balanceOf(bob), 500);
        assertEq(proxy.balanceOf(charlie), 500);
    }

    function test_transfer_Success_ZeroAmount() public {
        proxy.grantRole(minterRole, alice);
        vm.prank(alice);
        proxy.mint(bob, 1000);

        vm.expectEmit(true, true, true, true, address(proxy));
        emit IERC20.Transfer(bob, charlie, 0);

        vm.prank(bob);
        bool success = proxy.transfer(charlie, 0);

        assertTrue(success);
        assertEq(proxy.balanceOf(bob), 1000);
        assertEq(proxy.balanceOf(charlie), 0);
    }

    function test_transfer_Success_AllBalance() public {
        proxy.grantRole(minterRole, alice);
        vm.prank(alice);
        proxy.mint(bob, 1000);

        vm.expectEmit(true, true, true, true, address(proxy));
        emit IERC20.Transfer(bob, charlie, 1000);

        vm.prank(bob);
        bool success = proxy.transfer(charlie, 1000);

        assertTrue(success);
        assertEq(proxy.balanceOf(bob), 0);
        assertEq(proxy.balanceOf(charlie), 1000);
    }

    function test_transfer_Success_Fuzz(uint256 _mintAmount, uint256 _transferAmount) public {
        vm.assume(_transferAmount <= _mintAmount);

        proxy.grantRole(minterRole, alice);

        vm.prank(alice);
        proxy.mint(bob, _mintAmount);

        vm.expectEmit(true, true, true, true, address(proxy));
        emit IERC20.Transfer(bob, charlie, _transferAmount);

        vm.prank(bob);
        bool success = proxy.transfer(charlie, _transferAmount);

        assertTrue(success);
        assertEq(proxy.balanceOf(bob), _mintAmount - _transferAmount);
        assertEq(proxy.balanceOf(charlie), _transferAmount);
    }

    function test_transfer_Revert_BlacklistedSender() public {
        proxy.grantRole(minterRole, alice);
        proxy.grantRole(blacklisterRole, alice);

        vm.prank(alice);
        proxy.mint(bob, 1000);

        vm.prank(alice);
        proxy.addToBlacklist(bob);

        vm.expectRevert(abi.encodeWithSelector(IWXRPToken.Blacklisted.selector, bob));
        vm.prank(bob);
        proxy.transfer(charlie, 500);
    }

    function test_transfer_Revert_BlacklistedReceiver() public {
        proxy.grantRole(minterRole, alice);
        proxy.grantRole(blacklisterRole, alice);

        vm.prank(alice);
        proxy.mint(bob, 1000);

        vm.prank(alice);
        proxy.addToBlacklist(charlie);

        vm.expectRevert(abi.encodeWithSelector(IWXRPToken.Blacklisted.selector, charlie));
        vm.prank(bob);
        proxy.transfer(charlie, 500);
    }

    function test_transfer_Revert_WhenPaused() public {
        proxy.grantRole(minterRole, alice);
        proxy.grantRole(pauserRole, alice);

        vm.prank(alice);
        proxy.mint(bob, 1000);

        vm.prank(alice);
        proxy.pause();

        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector, address(proxy));
        vm.prank(bob);
        proxy.transfer(charlie, 500);
    }

    function test_transfer_Revert_InsufficientBalance() public {
        proxy.grantRole(minterRole, alice);
        vm.prank(alice);
        proxy.mint(bob, 500);

        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, bob, 500, 1000));
        vm.prank(bob);
        proxy.transfer(charlie, 1000);
    }

    function test_transfer_Revert_ToZeroAddress() public {
        proxy.grantRole(minterRole, alice);
        vm.prank(alice);
        proxy.mint(bob, 1000);

        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidReceiver.selector, address(0)));
        vm.prank(bob);
        proxy.transfer(address(0), 500);
    }

    // ============================================
    //                 TRANSFERFROM
    // ============================================

    function test_transferFrom_Success() public {
        proxy.grantRole(minterRole, alice);
        vm.prank(alice);
        proxy.mint(bob, 1000);

        vm.prank(bob);
        proxy.approve(alice, 500);

        vm.expectEmit(true, true, true, true, address(proxy));
        emit IERC20.Transfer(bob, charlie, 500);

        vm.prank(alice);
        bool success = proxy.transferFrom(bob, charlie, 500);

        assertTrue(success);
        assertEq(proxy.balanceOf(bob), 500);
        assertEq(proxy.balanceOf(charlie), 500);
        assertEq(proxy.allowance(bob, alice), 0);
    }

    function test_transferFrom_Success_ZeroAmount() public {
        proxy.grantRole(minterRole, alice);
        vm.prank(alice);
        proxy.mint(bob, 1000);

        vm.prank(bob);
        proxy.approve(alice, 500);

        vm.expectEmit(true, true, true, true, address(proxy));
        emit IERC20.Transfer(bob, charlie, 0);

        vm.prank(alice);
        bool success = proxy.transferFrom(bob, charlie, 0);

        assertTrue(success);
        assertEq(proxy.balanceOf(bob), 1000);
        assertEq(proxy.balanceOf(charlie), 0);
        assertEq(proxy.allowance(bob, alice), 500);
    }

    function test_transferFrom_Success_ExactAllowance() public {
        proxy.grantRole(minterRole, alice);
        vm.prank(alice);
        proxy.mint(bob, 1000);

        vm.prank(bob);
        proxy.approve(alice, 500);

        vm.expectEmit(true, true, true, true, address(proxy));
        emit IERC20.Transfer(bob, charlie, 500);

        vm.prank(alice);
        bool success = proxy.transferFrom(bob, charlie, 500);

        assertTrue(success);
        assertEq(proxy.allowance(bob, alice), 0);
    }

    function test_transferFrom_Success_Fuzz(uint256 _amount) public {
        vm.assume(_amount > 0);
        vm.assume(_amount < type(uint256).max);

        proxy.grantRole(minterRole, eve);

        vm.prank(eve);
        proxy.mint(bob, _amount);

        vm.prank(bob);
        proxy.approve(alice, _amount);

        vm.expectEmit(true, true, true, true, address(proxy));
        emit IERC20.Transfer(bob, charlie, _amount);

        vm.prank(alice);
        bool success = proxy.transferFrom(bob, charlie, _amount);

        assertTrue(success);
        assertEq(proxy.balanceOf(bob), 0);
        assertEq(proxy.balanceOf(charlie), _amount);
        assertEq(proxy.allowance(bob, alice), 0);
    }

    function test_transferFrom_Revert_BlacklistedFrom() public {
        proxy.grantRole(minterRole, alice);
        proxy.grantRole(blacklisterRole, alice);

        vm.prank(alice);
        proxy.mint(bob, 1000);

        vm.prank(bob);
        proxy.approve(alice, 500);

        vm.prank(alice);
        proxy.addToBlacklist(bob);

        vm.expectRevert(abi.encodeWithSelector(IWXRPToken.Blacklisted.selector, bob));
        vm.prank(alice);
        proxy.transferFrom(bob, charlie, 500);
    }

    function test_transferFrom_Revert_BlacklistedTo() public {
        proxy.grantRole(minterRole, alice);
        proxy.grantRole(blacklisterRole, alice);

        vm.prank(alice);
        proxy.mint(bob, 1000);

        vm.prank(bob);
        proxy.approve(alice, 500);

        vm.prank(alice);
        proxy.addToBlacklist(charlie);

        vm.expectRevert(abi.encodeWithSelector(IWXRPToken.Blacklisted.selector, charlie));
        vm.prank(alice);
        proxy.transferFrom(bob, charlie, 500);
    }

    function test_transferFrom_Revert_BlacklistedSender() public {
        proxy.grantRole(minterRole, alice);
        proxy.grantRole(blacklisterRole, alice);

        vm.prank(alice);
        proxy.mint(bob, 1000);

        vm.prank(bob);
        proxy.approve(charlie, 500);

        vm.prank(alice);
        proxy.addToBlacklist(charlie);

        vm.expectRevert(abi.encodeWithSelector(IWXRPToken.Blacklisted.selector, charlie));
        vm.prank(charlie);
        proxy.transferFrom(bob, dave, 500);
    }

    function test_transferFrom_Revert_WhenPaused() public {
        proxy.grantRole(minterRole, alice);
        proxy.grantRole(pauserRole, alice);

        vm.prank(alice);
        proxy.mint(bob, 1000);

        vm.prank(bob);
        proxy.approve(alice, 500);

        vm.prank(alice);
        proxy.pause();

        vm.expectRevert(PausableUpgradeable.EnforcedPause.selector, address(proxy));
        vm.prank(alice);
        proxy.transferFrom(bob, charlie, 500);
    }

    function test_transferFrom_Revert_InsufficientBalance() public {
        proxy.grantRole(minterRole, alice);
        vm.prank(alice);
        proxy.mint(bob, 500);

        vm.prank(bob);
        proxy.approve(alice, 1000);

        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientBalance.selector, bob, 500, 1000));
        vm.prank(alice);
        proxy.transferFrom(bob, charlie, 1000);
    }

    function test_transferFrom_Revert_InsufficientAllowance() public {
        proxy.grantRole(minterRole, alice);
        vm.prank(alice);
        proxy.mint(bob, 1000);

        vm.prank(bob);
        proxy.approve(alice, 400);

        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, alice, 400, 500));
        vm.prank(alice);
        proxy.transferFrom(bob, charlie, 500);
    }

    function test_transferFrom_Revert_FromZeroAddress() public {
        // When transferFrom with address(0), it first checks allowance (which is 0) before validating sender.
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, alice, 0, 500));
        vm.prank(alice);
        proxy.transferFrom(address(0), charlie, 500);
    }

    function test_transferFrom_Revert_ToZeroAddress() public {
        proxy.grantRole(minterRole, alice);
        vm.prank(alice);
        proxy.mint(bob, 1000);

        vm.prank(bob);
        proxy.approve(alice, 500);

        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidReceiver.selector, address(0)));
        vm.prank(alice);
        proxy.transferFrom(bob, address(0), 500);
    }

    // ============================================
    //         VIEW FUNCTIONS & CONSTANTS
    // ============================================

    function test_decimals() public view {
        assertEq(proxy.decimals(), 6);
    }

    function test_constants() public view {
        assertEq(proxy.BLACKLISTER_ROLE(), keccak256("BLACKLISTER_ROLE"));
        assertEq(proxy.PAUSER_ROLE(), keccak256("PAUSER_ROLE"));
        assertEq(proxy.MINTER_ROLE(), keccak256("MINTER_ROLE"));
        assertEq(proxy.BURNER_ROLE(), keccak256("BURNER_ROLE"));
        assertEq(proxy.DEFAULT_ADMIN_ROLE(), 0x00);
    }

    function test_name() public view {
        assertEq(proxy.name(), "Wrapped XRP");
    }

    function test_symbol() public view {
        assertEq(proxy.symbol(), "wXRP");
    }

    function test_totalSupply_Initial() public view {
        assertEq(proxy.totalSupply(), 0);
    }

    function test_balanceOf_Initial() public view {
        assertEq(proxy.balanceOf(alice), 0);
        assertEq(proxy.balanceOf(address(0)), 0);
    }

    function test_allowance_Initial() public view {
        assertEq(proxy.allowance(alice, bob), 0);
        assertEq(proxy.allowance(address(0), alice), 0);
    }

    function test_isBlacklisted_Initial() public view {
        assertFalse(proxy.isBlacklisted(alice));
        assertFalse(proxy.isBlacklisted(address(0)));
    }

    function test_paused_Initial() public view {
        assertFalse(proxy.paused());
    }

    // ============================================
    //          INHERITED ERC20 FUNCTIONS
    // ============================================

    function test_approve_Success() public {
        vm.expectEmit(true, true, true, true, address(proxy));
        emit IERC20.Approval(alice, bob, 1000);

        vm.prank(alice);
        bool success = proxy.approve(bob, 1000);

        assertTrue(success);
        assertEq(proxy.allowance(alice, bob), 1000);
    }

    function test_approve_Success_ZeroAmount() public {
        vm.prank(alice);
        proxy.approve(bob, 1000);

        vm.expectEmit(true, true, true, true, address(proxy));
        emit IERC20.Approval(alice, bob, 0);

        vm.prank(alice);
        bool success = proxy.approve(bob, 0);

        assertTrue(success);
        assertEq(proxy.allowance(alice, bob), 0);
    }

    function test_approve_Revert_ZeroAddress() public {
        vm.expectRevert(abi.encodeWithSelector(IERC20Errors.ERC20InvalidSpender.selector, address(0)));
        vm.prank(alice);
        proxy.approve(address(0), 1000);
    }

    // ============================================
    //                 INTEGRATION
    // ============================================

    function test_integration_BurnTokensFromBlacklisted() public {
        proxy.grantRole(minterRole, alice);
        proxy.grantRole(blacklisterRole, alice);

        vm.prank(alice);
        proxy.mint(bob, 100);

        vm.prank(alice);
        proxy.addToBlacklist(bob);

        AtomicBurner burner = new AtomicBurner();

        proxy.grantRole(burnerRole, address(burner));
        proxy.grantRole(blacklisterRole, address(burner));

        vm.expectEmit(true, true, true, true, address(proxy));
        emit IWXRPToken.RemovedFromBlacklist(bob);

        vm.expectEmit(true, true, true, true, address(proxy));
        emit IERC20.Transfer(bob, address(0), 100);

        vm.expectEmit(true, true, true, true, address(proxy));
        emit IWXRPToken.AddedToBlacklist(bob);

        burner.burnBlacklisted(address(proxy), bob, 100);

        assertTrue(proxy.isBlacklisted(bob));
        assertEq(proxy.balanceOf(bob), 0);
        assertEq(proxy.totalSupply(), 0);
    }

    function test_integration_BurnTokensWhenPaused() public {
        proxy.grantRole(minterRole, alice);
        proxy.grantRole(pauserRole, alice);

        vm.prank(alice);
        proxy.mint(bob, 100);

        vm.prank(alice);
        proxy.pause();

        AtomicBurner burner = new AtomicBurner();

        proxy.grantRole(burnerRole, address(burner));
        proxy.grantRole(pauserRole, address(burner));

        vm.expectEmit(true, true, true, true, address(proxy));
        emit PausableUpgradeable.Unpaused(address(burner));

        vm.expectEmit(true, true, true, true, address(proxy));
        emit IERC20.Transfer(bob, address(0), 100);

        vm.expectEmit(true, true, true, true, address(proxy));
        emit PausableUpgradeable.Paused(address(burner));

        burner.burnPaused(address(proxy), bob, 100);

        assertTrue(proxy.paused());
        assertEq(proxy.balanceOf(bob), 0);
        assertEq(proxy.totalSupply(), 0);
    }

    // ============================================
    //                UPGRADEABILITY
    // ============================================

    function test_upgrade_Success() public {
        // Deploy new implementation.
        WXRPTokenV2 newImpl = new WXRPTokenV2();

        // Record initial state.
        uint256 initialSupply = proxy.totalSupply();

        // Only proxy admin can upgrade.
        vm.prank(dave);
        proxyAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(address(proxy)),
            address(newImpl),
            abi.encodeWithSelector(WXRPTokenV2.reinitialize.selector, eve)
        );

        // Verify upgrade successful.
        WXRPTokenV2 upgradedProxy = WXRPTokenV2(address(proxy));
        assertEq(upgradedProxy.name(), "Upgraded");
        assertEq(upgradedProxy.symbol(), "UPG");
        assertEq(upgradedProxy.decimals(), 6);
        assertEq(upgradedProxy.totalSupply(), initialSupply);
        assertTrue(upgradedProxy.hasRole(DEFAULT_ADMIN_ROLE, eve));

        // Verify state preservation.
        assertTrue(upgradedProxy.hasRole(DEFAULT_ADMIN_ROLE, address(this)));
    }

    function test_upgrade_Revert_Unauthorized() public {
        WXRPTokenV2 newImpl = new WXRPTokenV2();

        // Non-admin cannot upgrade.
        vm.expectRevert();
        vm.prank(alice);
        proxyAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(address(proxy)),
            address(newImpl),
            abi.encodeWithSelector(WXRPTokenV2.reinitialize.selector, eve)
        );
    }

    function test_upgrade_WithStatePreservation() public {
        // Setup initial state.
        proxy.grantRole(minterRole, alice);
        proxy.grantRole(blacklisterRole, alice);

        vm.prank(alice);
        proxy.mint(bob, 1000);

        vm.prank(alice);
        proxy.addToBlacklist(charlie);

        uint256 preUpgradeBalance = proxy.balanceOf(bob);
        bool preUpgradeBlacklisted = proxy.isBlacklisted(charlie);

        // Upgrade.
        WXRPTokenV2 newImpl = new WXRPTokenV2();
        vm.prank(dave);
        proxyAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(address(proxy)),
            address(newImpl),
            abi.encodeWithSelector(WXRPTokenV2.reinitialize.selector, eve)
        );

        WXRPTokenV2 upgradedProxy = WXRPTokenV2(address(proxy));

        // Verify state preserved.
        assertEq(upgradedProxy.balanceOf(bob), preUpgradeBalance);
        assertEq(upgradedProxy.isBlacklisted(charlie), preUpgradeBlacklisted);
        assertTrue(upgradedProxy.hasRole(minterRole, alice));

        // Verify new functionality works.
        assertEq(upgradedProxy.name(), "Upgraded");
        assertEq(upgradedProxy.symbol(), "UPG");
    }

    function test_upgrade_ReinitializeOnce() public {
        WXRPTokenV2 newImpl = new WXRPTokenV2();

        vm.prank(dave);
        proxyAdmin.upgradeAndCall(
            ITransparentUpgradeableProxy(address(proxy)),
            address(newImpl),
            abi.encodeWithSelector(WXRPTokenV2.reinitialize.selector, eve)
        );

        WXRPTokenV2 upgradedProxy = WXRPTokenV2(address(proxy));

        // Should not be able to reinitialize again.
        vm.expectRevert();
        upgradedProxy.reinitialize(eve);
    }
}
