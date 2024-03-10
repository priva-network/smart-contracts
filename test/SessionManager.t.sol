// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/SessionManager.sol";

import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract NodeRegistryMock is INodeRegistry {
    struct Node {
        string ipAddress;
        address owner;
        bool isActive;
    }

    mapping(uint => Node) public nodes;
    uint public nodeCount;

    function registerNode(string memory _ipAddress, address _owner) public {
        nodes[nodeCount] = Node(_ipAddress, _owner, true);
        nodeCount++;
    }

    function setNodeActiveStatus(uint nodeId, bool isActive) public {
        nodes[nodeId].isActive = isActive;
    }

    function nodeExists(uint nodeId) external pure override returns (bool) {
        return nodeId < nodeCount;
    }

    function getNodeDetails(uint nodeId) external pure override returns (string memory, address, bool) {
        require(nodeId < nodeCount, "Node does not exist");
        Node memory node = nodes[nodeId];
        return (node.ipAddress, node.owner, node.isActive);
    }
}

contract SessionManagerTest is Test {
    using ECDSA for bytes32;

    SessionManager sessionManager;
    NodeRegistryMock nodeRegistryMock;

    uint256 internal nodePrivateKey;
    address internal nodeAddress;
    string internal nodeIpAddress = "127.0.0.1";
    uint internal nodeId = 0;

    function setUp() public {
        nodeRegistryMock = new NodeRegistryMock();
        sessionManager = new SessionManager(address(nodeRegistryMock));

        // Register a node in the mock registry
        nodePrivateKey = 0x0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef;
        nodeAddress = vm.addr(nodePrivateKey);
        nodeRegistryMock.registerNode(nodeIpAddress, nodeAddress);
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
        address user = address(this);

        // Setup: User deposits ETH and opens a session
        vm.deal(user, depositAmount);
        sessionManager.deposit{value: depositAmount}();
        sessionManager.openSession(computeCostLimit, nodeId);

        // Session details to be signed
        uint256 sessionId = 0;
        uint256 amountPaid = 0.3 ether;

        // Create the message hash to be signed
        bytes32 messageHash = keccak256(abi.encodePacked(sessionId, amountPaid));

        // Generate the signature
        bytes32 ethSignedMessageHash = messageHash.toEthSignedMessageHash();
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(nodePrivateKey, ethSignedMessageHash);

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
