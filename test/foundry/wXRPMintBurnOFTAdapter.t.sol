// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import { console } from "forge-std/Test.sol";

import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { ILayerZeroEndpointV2 } from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import { TestHelperOz5, EndpointV2 } from "@layerzerolabs/test-devtools-evm-foundry/contracts/TestHelperOz5.sol";
import { IMintableBurnable } from "@layerzerolabs/oft-evm/contracts/interfaces/IMintableBurnable.sol";
import { Origin } from "@layerzerolabs/oapp-evm/contracts/oapp/interfaces/IOAppReceiver.sol";
import { SendParam } from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import { MessagingFee } from "@layerzerolabs/oapp-evm/contracts/oapp/OAppSender.sol";
import { OptionsBuilder } from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";

import { WXRPToken } from "contracts/WXRPToken.sol";
import { WXRPMintBurnOFTAdapter } from "contracts/WXRPMintBurnOFTAdapter.sol";

contract WXRPMintBurnOFTAdapterTest is TestHelperOz5 {
    using OptionsBuilder for bytes;

    WXRPToken token;
    WXRPMintBurnOFTAdapter maba;
    EndpointV2 endpoint;
    address mockPeer = address(0x11);

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

    uint32 public constant EID_A = 1;
    uint32 public constant EID_B = 2;

    function _atb32(address _address) internal pure returns (bytes32) {
        return bytes32(uint256(uint160(_address)));
    }

    function setUp() public override {
        // Label accounts.
        vm.label(address(this), "this");
        vm.label(alice, "alice");
        vm.label(bob, "bob");
        vm.label(charlie, "charlie");
        vm.label(dave, "dave");
        vm.label(eve, "eve");

        // Deploy Endpoint mock.
        setUpEndpoints(2, LibraryType.UltraLightNode);
        endpoint = EndpointV2(endpoints[EID_A]);

        // Deploy token.
        WXRPToken impl = new WXRPToken();
        TransparentUpgradeableProxy _proxy = new TransparentUpgradeableProxy(
            address(impl),
            alice,
            abi.encodeWithSelector(WXRPToken.initialize.selector, bob)
        );
        token = WXRPToken(address(_proxy));

        // Cache role constants.
        minterRole = token.MINTER_ROLE();
        burnerRole = token.BURNER_ROLE();
        blacklisterRole = token.BLACKLISTER_ROLE();
        pauserRole = token.PAUSER_ROLE();

        // Deploy MABA.
        maba = new WXRPMintBurnOFTAdapter(
            address(token),
            IMintableBurnable(address(token)),
            address(endpoint),
            charlie
        );

        // Grant minter and burner roles to MABA.
        vm.prank(bob);
        token.grantRole(minterRole, address(maba));
        vm.prank(bob);
        token.grantRole(burnerRole, address(maba));

        // Peer with mock token.
        vm.prank(charlie);
        maba.setPeer(EID_B, _atb32(mockPeer));
    }

    function test_setup() public view {
        assertTrue(token.hasRole(token.MINTER_ROLE(), address(maba)));
        assertTrue(token.hasRole(token.BURNER_ROLE(), address(maba)));
        assertEq(maba.peers(EID_B), _atb32(mockPeer));
    }

    function test_constructor() public view {
        assertEq(address(maba.token()), address(token));
        assertEq(address(maba.minterBurner()), address(token));
        assertEq(maba.owner(), charlie);
        assertEq(address(maba.endpoint()), address(endpoint));
        assertEq(endpoint.delegates(address(maba)), charlie);
    }

    function test_send_Success() public {
        vm.prank(bob);
        token.grantRole(minterRole, address(bob));

        vm.prank(bob);
        token.mint(address(dave), 100);

        SendParam memory sendParam = SendParam({
            dstEid: EID_B,
            to: _atb32(address(eve)),
            amountLD: 100,
            minAmountLD: 100,
            extraOptions: OptionsBuilder.newOptions().addExecutorLzReceiveOption(100_000, 0),
            composeMsg: hex"",
            oftCmd: hex""
        });
        MessagingFee memory fee = maba.quoteSend(sendParam, false);

        vm.expectEmit(true, true, true, true, address(token));
        emit IERC20.Transfer(address(dave), address(0), 100);

        vm.deal(address(dave), fee.nativeFee);
        vm.prank(dave);
        maba.send{ value: fee.nativeFee }(sendParam, fee, dave);

        assertEq(token.balanceOf(dave), 0);
    }

    function test_lzReceive_Success() public {
        Origin memory origin = Origin({ srcEid: EID_B, sender: _atb32(mockPeer), nonce: 1 });
        bytes memory message = abi.encodePacked(_atb32(address(bob)), uint64(100));
        vm.prank(address(endpoint));
        maba.lzReceive(origin, bytes32(0), message, address(0), bytes(""));

        assertEq(token.balanceOf(bob), 100);
    }
}
