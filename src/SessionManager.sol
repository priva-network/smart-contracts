// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

interface INodeRegistry {
    function nodeExists(uint nodeId) external view returns (bool);
    function getNodeDetails(uint nodeId) external view returns (string memory, address, bool);
}

contract SessionManager {
    using ECDSA for bytes32;

    struct Session {
        uint256 startTime;
        uint256 computeCostLimit;
        address user;
        uint nodeId;
        bool isActive;
        uint256 amountPaid;
    }

    address public owner;
    mapping(address => uint256) public deposits;
    mapping(uint256 => Session) public sessions;
    uint256 public sessionCount;
    uint256 public constant SESSION_TIMEOUT = 48 hours;

    event SessionOpened(uint256 sessionId, address user, uint node);
    event SessionClosed(uint256 sessionId, address user, uint node, uint256 amountPaid);

    INodeRegistry public nodeRegistry;

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can call this function.");
        _;
    }

    constructor(address _nodeRegistryAddress) {
        owner = msg.sender;
        nodeRegistry = INodeRegistry(_nodeRegistryAddress);
    }

    // Allow users to deposit ETH into the contract
    function deposit() public payable {
        require(msg.value > 0, "Deposit must be greater than 0");
        deposits[msg.sender] += msg.value;
    }

    // Open a session after verifying user has enough deposit
    // Simplified to not check if node exists for brevity
    function openSession(uint256 _computeCostLimit, uint _nodeId) public {
        require(deposits[msg.sender] >= _computeCostLimit, "Insufficient deposit for compute cost limit");
        require(nodeRegistry.nodeExists(_nodeId), "Node does not exist");

        sessions[sessionCount] = Session(block.timestamp, _computeCostLimit, msg.sender, _nodeId, true, 0);
        emit SessionOpened(sessionCount, msg.sender, _nodeId);
        sessionCount++;
    }

    function closeSession(uint256 _sessionId, uint256 _amountPaid, bytes memory _signature) public {
        Session storage session = sessions[_sessionId];

        require(session.isActive, "Session is not active");
        require(session.user == msg.sender, "Only the session user can close the session");
        require(deposits[msg.sender] >= _amountPaid, "Insufficient deposit to cover payment");
        
        // Construct the message that was signed
        bytes32 messageHash = keccak256(abi.encodePacked(_sessionId, _amountPaid));

        // Retrieve the node address from your getNodeDetails function
        (, address nodeAddress, ) = nodeRegistry.getNodeDetails(session.nodeId);

        // Verify the signature
        require(isValidSignature(nodeAddress, messageHash, _signature), "Invalid signature");

        session.isActive = false;
        deposits[msg.sender] -= _amountPaid;
        session.amountPaid = _amountPaid;

        emit SessionClosed(_sessionId, msg.sender, session.nodeId, _amountPaid);
    }

    function isValidSignature(address _addressToMatch, bytes32 _hash, bytes memory _signature) public pure returns (bool) {
        require(_addressToMatch != address(0), "Invalid address");

        bytes32 ethSignedMessageHash = _hash.toEthSignedMessageHash();
        address recoveredSigner = ethSignedMessageHash.recover(_signature);

        return recoveredSigner == _addressToMatch;
    }

    // Utility function to split the signature into its components
    function splitSignature(bytes memory _sig)
        internal
        pure
        returns (bytes32 r, bytes32 s, uint8 v)
    {
        require(_sig.length == 65, "Invalid signature length");

        assembly {
            // first 32 bytes, after the length prefix
            r := mload(add(_sig, 32))
            // second 32 bytes
            s := mload(add(_sig, 64))
            // final byte (first byte of the next 32 bytes)
            v := byte(0, mload(add(_sig, 96)))
        }

        // Adjust for Ethereum's signing quirks
        if (v < 27) v += 27;
    }

    function claimPayment(uint _sessionId) external {
        Session storage session = sessions[_sessionId];
        
        require(!session.isActive || block.timestamp - session.startTime > SESSION_TIMEOUT, "Session not closed or time limit not reached");
        require(nodeRegistry.nodeExists(session.nodeId), "Node does not exist");
        require(session.amountPaid > 0, "No payment to claim");
        
        // Get the node owner's address from the node registry
        (, address nodeOwner, ) = nodeRegistry.getNodeDetails(session.nodeId);
        require(msg.sender == nodeOwner, "Only the node owner can claim payment");
        
        payable(nodeOwner).transfer(session.amountPaid);
    }

    // Allow users to withdraw their unused deposit
    function withdrawDeposit(uint256 _amount) public {
        require(deposits[msg.sender] >= _amount, "Insufficient deposit");
        deposits[msg.sender] -= _amount;
        payable(msg.sender).transfer(_amount);
    }
}
