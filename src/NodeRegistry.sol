// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract NodeRegistry {
    struct Node {
        string ipAddress;
        address owner;
    }

    mapping(uint => Node) public nodes;
    mapping(address => uint) public nodeOwnerToId;
    // Initialize to 1 to avoid confusion with the default value of 0
    // E.g. nodeOwnerToId for an address that has not registered a node will return 0
    // This could be interpreted as the ID of the first node, which is incorrect.
    uint public nodeIndex = 1;

    // Event declarations
    event NodeRegistered(uint indexed nodeId, string ipAddress, address owner);
    event NodeIPAddressUpdated(uint indexed nodeId, string newIPAddress);

    /**
     * Registers a new node with the provided IP address.
     * Each new node is assigned an incrementing ID.
     * 
     * @param _ipAddress The IP address of the node to register.
     * @param _owner The address of the node's owner.
     */
    function registerNode(string memory _ipAddress, address _owner) public {
        nodes[nodeIndex] = Node(_ipAddress, _owner);
        nodeOwnerToId[_owner] = nodeIndex;
        emit NodeRegistered(nodeIndex, _ipAddress, _owner);
        nodeIndex++;
    }

    /**
     * Sets the IP address of a specified node.
     * 
     * @param _nodeId The ID of the node to update.
     * @param _ipAddress The new IP address of the node.
     */
    function setNodeIPAddress(uint _nodeId, string memory _ipAddress) public {
        // TODO: Should make sure the sender of this tx is the owner of the node
        require(_nodeId < nodeIndex, "Node does not exist.");
        nodes[_nodeId].ipAddress = _ipAddress;
        emit NodeIPAddressUpdated(_nodeId, _ipAddress);
    }

    /**
     * Gets the ID of the node owned by the specified address.
     * 
     * @param _owner The address of the node's owner.
     * @return The ID of the node owned by the specified address.
     */
    function getNodeIdByOwner(address _owner) public view returns (uint) {
        require(nodeOwnerToId[_owner] < nodeIndex, "Node does not exist.");
        return nodeOwnerToId[_owner];
    }

    /**
     * Gets the details of a specified node.
     * 
     * @param _nodeId The ID of the node to retrieve.
     * @return The IP address, owner address
     */
    function getNodeDetails(uint _nodeId) public view returns (string memory, address) {
        require(_nodeId < nodeIndex, "Node does not exist.");
        Node memory node = nodes[_nodeId];
        return (node.ipAddress, node.owner);
    }

    /**
     * Checks if a node with the specified ID exists.
     * 
     * @param nodeId The ID of the node to check.
     * @return True if the node exists, false otherwise.
     */
    function nodeExists(uint nodeId) public view returns (bool) {
        return nodeId < nodeIndex;
    }
}
