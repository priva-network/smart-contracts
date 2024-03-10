// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/SessionManager.sol";

contract NodeRegistryMock is INodeRegistry {
    function nodeExists(uint nodeId) external pure override returns (bool) {
        return nodeId < 10; // Simulate that nodes with ID < 10 exist
    }

    function getNodeDetails(uint nodeId) external pure override returns (string memory, address, bool) {
        address nodeAddress = address(uint160(uint256(keccak256(abi.encodePacked(uint256(nodeId))))));
        return ("127.0.0.1", nodeAddress, true); // Simulate node details
    }
}

contract SessionManagerTest is Test {
    SessionManager sessionManager;
    NodeRegistryMock nodeRegistryMock;

    function setUp() public {
        nodeRegistryMock = new NodeRegistryMock();
        sessionManager = new SessionManager(address(nodeRegistryMock));
    }

    function testDeposit() public {
        address user = address(this);
        uint256 depositAmount = 1 ether;
        
        vm.deal(user, depositAmount); // Provide the test contract with 1 ETH
        sessionManager.deposit{value: depositAmount}();
        
        assertEq(sessionManager.deposits(user), depositAmount, "Deposit should match the sent amount");
    }

    function testOpenSession() public {
        address user = address(this);
        uint256 depositAmount = 1 ether;
        uint256 computeCostLimit = 0.5 ether;
        uint nodeId = 1;
        
        vm.deal(address(this), depositAmount); // Provide the test contract with 1 ETH
        sessionManager.deposit{value: depositAmount}();
        
        vm.startPrank(user);
        sessionManager.openSession(computeCostLimit, nodeId);
        (, uint256 sessionCostLimit, address sessionUser, uint sessionNodeId,,) = sessionManager.sessions(0);
        assertEq(sessionCostLimit, computeCostLimit, "Session cost limit should match the input");
        assertEq(sessionUser, user, "Session should be opened by the user");
        assertEq(sessionNodeId, nodeId, "Session should be opened for the specified node");
        vm.stopPrank();
    }

    function testFailOpenSessionWithInvalidNode() public {
        uint256 depositAmount = 1 ether;
        uint256 computeCostLimit = 0.5 ether;
        uint invalidNodeId = 11; // Node ID not recognized by NodeRegistryMock
        
        vm.deal(address(this), depositAmount); // Provide the test contract with 1 ETH
        sessionManager.deposit{value: depositAmount}();

        // Expect a specific revert error message
        bytes memory expectedRevertMessage = abi.encodeWithSignature("Error(string)", "Node does not exist");
        vm.expectRevert(expectedRevertMessage);
        
        sessionManager.openSession(computeCostLimit, invalidNodeId); // This should fail
    }

    function testFailOpenSessionWithInsufficientDeposit() public {
        uint256 depositAmount = 0.5 ether;
        uint256 computeCostLimit = 1 ether;
        uint nodeId = 1;
        
        vm.deal(address(this), depositAmount); // Provide the test contract with 0.5 ETH
        sessionManager.deposit{value: depositAmount}();

        // Expect a specific revert error message
        bytes memory expectedRevertMessage = abi.encodeWithSignature("Error(string)", "Insufficient deposit for compute cost limit");
        vm.expectRevert(expectedRevertMessage);
        
        sessionManager.openSession(computeCostLimit, nodeId); // This should fail
    }

    function testCloseSessionSuccessfully() public {
        uint256 depositAmount = 1 ether;
        uint256 computeCostLimit = 0.5 ether;
        uint nodeId = 1; // Assuming this node exists in the NodeRegistryMock
        address user = address(this);

        // Setup: User deposits ETH and opens a session
        vm.deal(user, depositAmount);
        sessionManager.deposit{value: depositAmount}();
        sessionManager.openSession(computeCostLimit, nodeId);

        // Node's address and private key (for test purposes only!)
        // Foundry uses test private keys starting with `0x...` for its predefined accounts.
        // address nodeAddress = vm.addr(1); // This uses Foundry's default accounts. Account 1 is just an example.
        uint256 privateKey = 0x01; // This should match the account

        // Session details to be signed
        uint256 sessionId = 0;
        uint256 amountPaid = 0.3 ether;

        // Create the message hash to be signed
        bytes32 message = keccak256(abi.encodePacked(sessionId, amountPaid));
        bytes32 ethSignedMessageHash = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", message)
        );

        // Generate the signature
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, ethSignedMessageHash);

        // Now you have a real signature (v, r, s) that you can pass to your contract function
        bytes memory mockSignature = abi.encodePacked(r, s, v);

        // Action: User closes the session
        vm.prank(user);
        sessionManager.closeSession(sessionId, amountPaid, mockSignature);

        // Assertions
        (,,,, bool sessionIsActive, uint256 sessionAmountPaid) = sessionManager.sessions(sessionId);
        assertFalse(sessionIsActive, "Session should be inactive after closing");
        assertEq(sessionAmountPaid, amountPaid, "Session amountPaid should match the amount paid");
        assertEq(sessionManager.deposits(user), 0.7 ether, "User's remaining deposit should be updated correctly");
    }


    // Add more tests here for closeSession, claimPayment, and withdrawDeposit functions
    // Including tests with fuzzing for deposit amounts, session IDs, node IDs, etc.
}
