import { COWShed, COWShedProxy, Call } from "src/COWShed.sol";
import { Test, Vm } from "forge-std/Test.sol";
import { COWShedFactory } from "src/COWShedFactory.sol";
import { BaseTest } from "./BaseTest.sol";

contract Stub {
    error Revert();

    function willRevert() external {
        revert Revert();
    }

    function callWithValue() external payable { }

    function returnUint() external pure returns (uint256) {
        return 420;
    }
}

contract COWShedTest is BaseTest {
    Stub stub = new Stub();

    function testExecuteHooks() external {
        // fund the proxy
        userProxyAddr.call{ value: 1 ether }("");

        Call[] memory calls = new Call[](2);
        calls[0] = Call({
            target: address(stub),
            value: 0.05 ether,
            allowFailure: false,
            callData: abi.encodeCall(stub.callWithValue, ())
        });
        calls[1] =
            Call({ target: address(stub), value: 0, allowFailure: true, callData: abi.encodeCall(stub.willRevert, ()) });
        bytes32 nonce = "1";

        (bytes32 r, bytes32 s, uint8 v) = _signForFactory(calls, nonce, user);
        vm.expectCall(address(stub), abi.encodeCall(stub.callWithValue, ()));
        vm.expectCall(address(stub), abi.encodeCall(stub.willRevert, ()));
        factory.executeHooks(calls, nonce, r, s, v);

        // same sig shouldnt work more than once
        vm.expectRevert(COWShedFactory.NonceAlreadyUsed.selector);
        factory.executeHooks(calls, nonce, r, s, v);

        assertEq(address(stub).balance, 0.05 ether, "didnt send value as expected");

        // test that allowFailure works as expected
        calls[1].allowFailure = false;
        nonce = "2";
        (r, s, v) = _signForProxy(userProxyAddr, calls, nonce, user);
        vm.expectCall(address(stub), abi.encodeCall(stub.callWithValue, ()));
        vm.expectCall(address(stub), abi.encodeCall(stub.willRevert, ()));
        vm.expectRevert(Stub.Revert.selector);
        userProxy.executeHooks(calls, nonce, r, s, v);
    }

    function testTrustedExecuteHooks() external {
        address addr = makeAddr("addr");
        assertFalse(COWShed(payable(userProxy)).trustedExecutors(addr), "should not be a trusted executor");

        Call[] memory calls = new Call[](1);
        calls[0] = Call({
            target: address(userProxy),
            callData: abi.encodeCall(COWShed.updateTrustedExecutor, (addr, true)),
            allowFailure: false,
            value: 0
        });
        bytes32 nonce = "1";
        (bytes32 r, bytes32 s, uint8 v) = _signForProxy(userProxyAddr, calls, nonce, user);
        userProxy.executeHooks(calls, nonce, r, s, v);

        vm.prank(addr);
        vm.expectCall(address(0), hex"1234");
        calls[0].target = address(0);
        calls[0].callData = hex"1234";
        userProxy.trustedExecuteHooks(calls);
    }

    function testUpdateTrustedHook() external {
        address addr = makeAddr("addr");
        assertFalse(COWShed(payable(userProxy)).trustedExecutors(addr), "should not be a trusted executor");

        Call[] memory calls = new Call[](1);
        calls[0] = Call({
            target: address(userProxy),
            callData: abi.encodeCall(COWShed.updateTrustedExecutor, (addr, true)),
            allowFailure: false,
            value: 0
        });
        bytes32 nonce = "1";
        (bytes32 r, bytes32 s, uint8 v) = _signForProxy(userProxyAddr, calls, nonce, user);
        userProxy.executeHooks(calls, nonce, r, s, v);

        assertTrue(COWShed(payable(userProxy)).trustedExecutors(addr), "should be a trusted executor");
    }

    function testUpdateImplementation() external {
        vm.prank(user.addr);
        userProxy.updateImplementation(address(stub));
        assertAdminAndImpl(userProxyAddr, user.addr, address(stub));
        assertEq(Stub(userProxyAddr).returnUint(), 420, "didnt update as expected");
    }

    function _sign(Call[] memory calls, bytes32 nonce, Vm.Wallet memory user)
        internal
        view
        returns (bytes32 r, bytes32 s, uint8 v)
    { }
}
