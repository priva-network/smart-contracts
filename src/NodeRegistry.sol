// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract NodeRegistry {
    struct Node {
        string ipAddress;
        address owner;
        bool isActive;
    }

    mapping(uint => Node) public nodes;
    uint public nodeCount;

    // Event declarations
    event NodeRegistered(uint indexed nodeId, string ipAddress, address owner, bool isActive);
    event NodeStatusChanged(uint indexed nodeId, bool isActive);

    /**
     * Registers a new node with the provided IP address.
     * Each new node is assigned an incrementing ID.
     * 
     * @param _ipAddress The IP address of the node to register.
     * @param _owner The address of the node's owner.
     */
    function registerNode(string memory _ipAddress, address _owner) public {
        nodes[nodeCount] = Node(_ipAddress, _owner, true);
        emit NodeRegistered(nodeCount, _ipAddress, _owner, true);
        nodeCount++;
    }

    /**
     * Sets the active status of a specified node.
     * 
     * @param _nodeId The ID of the node to update.
     * @param _isActive The new active status of the node.
     */
    function setNodeActiveStatus(uint _nodeId, bool _isActive) public {
        require(_nodeId < nodeCount, "Node does not exist.");
        nodes[_nodeId].isActive = _isActive;
        emit NodeStatusChanged(_nodeId, _isActive);
    }

    /**
     * Gets the details of a specified node.
     * 
     * @param _nodeId The ID of the node to retrieve.
     * @return The IP address, owner address, and active status of the node.
     */
    function getNodeDetails(uint _nodeId) public view returns (string memory, address, bool) {
        require(_nodeId < nodeCount, "Node does not exist.");
        Node memory node = nodes[_nodeId];
        return (node.ipAddress, node.owner, node.isActive);
    }

    /**
     * Checks if a node with the specified ID exists.
     * 
     * @param nodeId The ID of the node to check.
     * @return True if the node exists, false otherwise.
     */
    function nodeExists(uint nodeId) public view returns (bool) {
        return nodeId < nodeCount;
    }
}
