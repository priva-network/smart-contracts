// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/NodeRegistry.sol";

contract NodeRegistryTest is Test {
    NodeRegistry nodeRegistry;

    function setUp() public {
        nodeRegistry = new NodeRegistry();
    }

    function testRegisterNode() public {
        string memory testIp = "127.0.0.1";
        address testOwner = address(0x1);
        
        nodeRegistry.registerNode(testIp, testOwner);
        (string memory returnedIp, address returnedOwner, bool isActive) = nodeRegistry.getNodeDetails(0);
        
        assertEq(returnedIp, testIp);
        assertEq(returnedOwner, testOwner);
        assertTrue(isActive);
    }

    // Fuzz test for the registerNode function
    function testRegisterNodeWithFuzzing(string memory _ipAddress, address _owner) public {
        // Register a node with fuzzed IP address and owner
        nodeRegistry.registerNode(_ipAddress, _owner);
        
        // Verify the node count has incremented
        uint expectedNodeCount = 1;
        assertEq(nodeRegistry.nodeCount(), expectedNodeCount);

        // Retrieve the node details and verify they match the input
        (string memory returnedIp, address returnedOwner, bool isActive) = nodeRegistry.getNodeDetails(expectedNodeCount - 1);
        
        assertEq(returnedIp, _ipAddress);
        assertEq(returnedOwner, _owner);
        assertTrue(isActive);
    }

    function testSetNodeActiveStatus() public {
        string memory testIp = "127.0.0.1";
        address testOwner = address(0x1);

        nodeRegistry.registerNode(testIp, testOwner);
        nodeRegistry.setNodeActiveStatus(0, false);
        (string memory returnedIp, address returnedOwner, bool isActive) = nodeRegistry.getNodeDetails(0);

        assertEq(returnedIp, testIp);
        assertEq(returnedOwner, testOwner);
        assertFalse(isActive);
    }

    function testNodeExists() public {
        string memory testIp = "127.0.0.1";
        address testOwner = address(0x1);

        nodeRegistry.registerNode(testIp, testOwner);
        assertTrue(nodeRegistry.nodeExists(0));
        assertFalse(nodeRegistry.nodeExists(1));
    }
}
