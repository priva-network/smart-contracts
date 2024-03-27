// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

interface INodeRegistry {
    function nodeExists(uint nodeId) external view returns (bool);
    function isNodeActive(uint nodeId) external view returns (bool);
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
        uint256 amountClaimableByNodeOwner;
    }

    address public owner;
    mapping(address => uint256) public deposits;
    mapping(uint256 => Session) public sessions;
    // Initialize to 1 to avoid confusion with the default value of 0
    uint256 public sessionCount = 1;
    uint256 public constant SESSION_TIMEOUT = 48 hours;

    event SessionOpened(uint256 sessionId, address indexed user, uint node);
    event SessionClosed(uint256 sessionId, address indexed user, uint node, uint256 amountClaimableByNodeOwner);

    INodeRegistry public nodeRegistry;

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can call this function.");
        _;
    }

    constructor(address _nodeRegistryAddress) {
        owner = msg.sender;
        nodeRegistry = INodeRegistry(_nodeRegistryAddress);
    }

    /**
     * @dev Allows users to deposit ETH into the contract.
     */
    function deposit() external payable {
        require(msg.value > 0, "Deposit must be greater than 0");
        deposits[msg.sender] += msg.value;
    }

    /**
     * @dev Opens a session after verifying the user has enough deposit and the node exists.
     * @param _computeCostLimit The maximum amount of ETH the session can consume.
     * @param _nodeId The ID of the node to be used for the session.
     */
    function openSession(uint256 _computeCostLimit, uint _nodeId) public {
        require(deposits[msg.sender] >= _computeCostLimit, "Insufficient deposit for compute cost limit");
        require(nodeRegistry.nodeExists(_nodeId), "Node does not exist");
        require(nodeRegistry.isNodeActive(_nodeId), "Node is not active");

        sessions[sessionCount] = Session(block.timestamp, _computeCostLimit, msg.sender, _nodeId, true, 0);
        emit SessionOpened(sessionCount, msg.sender, _nodeId);
        sessionCount++;
    }

    /**
     * @dev Closes a session and handles payment.
     * @param _sessionId The ID of the session to close.
     * @param _amountPaid The amount of ETH paid for the session.
     * @param _signature The signature proving the node agrees with the payment amount.
     */
    function closeSession(uint256 _sessionId, uint256 _amountPaid, bytes memory _signature) public {
        Session storage session = sessions[_sessionId];

        require(session.isActive, "Session is not active");
        require(session.user == msg.sender, "Only the session user can close the session");
        require(session.computeCostLimit >= _amountPaid, "Amount paid exceeds compute cost limit");
        require(deposits[msg.sender] >= _amountPaid, "Insufficient deposit to cover payment");
        
        // Construct the message that was signed
        bytes32 messageHash = keccak256(abi.encodePacked(_sessionId, _amountPaid));

        // Retrieve the node address from your getNodeDetails function
        (, address nodeAddress, ) = nodeRegistry.getNodeDetails(session.nodeId);

        // Verify the signature
        require(isValidSignature(nodeAddress, messageHash, _signature), "Invalid signature");

        session.isActive = false;
        deposits[msg.sender] -= _amountPaid;
        session.amountClaimableByNodeOwner = _amountPaid;

        emit SessionClosed(_sessionId, msg.sender, session.nodeId, _amountPaid);
    }

    /**
     * @dev Verifies the signature of a message.
     * @param _addressToMatch The address expected to have created the signature.
     * @param _hash The hash of the signed message.
     * @param _signature The signature to verify.
     * @return bool Returns true if the signature is valid and matches the address.
     */
    function isValidSignature(address _addressToMatch, bytes32 _hash, bytes memory _signature) public pure returns (bool) {
        require(_addressToMatch != address(0), "Invalid address");

        bytes32 ethSignedMessageHash = _hash.toEthSignedMessageHash();
        address recoveredSigner = ethSignedMessageHash.recover(_signature);

        return recoveredSigner == _addressToMatch;
    }

    /**
     * @dev Allows the node owner to claim payment for a session.
     * @param _sessionId The ID of the session for which payment is being claimed.
     */
    function claimPayment(uint _sessionId) external {
        Session storage session = sessions[_sessionId];
        
        require(!session.isActive || block.timestamp - session.startTime > SESSION_TIMEOUT, "Session not closed or time limit not reached");
        require(nodeRegistry.nodeExists(session.nodeId), "Node does not exist");
        if (!session.isActive) {
            require(session.amountClaimableByNodeOwner > 0, "No payment to claim");
        }
        
        // Get the node owner's address from the node registry
        (, address nodeOwner, ) = nodeRegistry.getNodeDetails(session.nodeId);
        require(msg.sender == nodeOwner, "Only the node owner can claim payment");
        
        payable(nodeOwner).transfer(session.amountClaimableByNodeOwner);

        session.amountClaimableByNodeOwner = 0;
    }

    /**
     * @dev Retrieves the details of a session.
     * @param _sessionId The ID of the session to retrieve.
     * @return Session Returns the session struct associated with the given ID.
     */
    function getSessionDetails(uint _sessionId) external view returns (Session memory) {
        return sessions[_sessionId];
    }

    /**
     * @dev Allows users to withdraw their unused deposit.
     * @param _amount The amount of ETH to withdraw.
     */
    function withdraw(uint256 _amount) public {
        // TODO: Shouldn't be able to withdraw more than amount allocated towards sessions
        require(deposits[msg.sender] >= _amount, "Insufficient deposit");
        deposits[msg.sender] -= _amount;
        payable(msg.sender).transfer(_amount);
    }

    /**
     * @dev Returns the balance of a user's deposit.
     * @param _user The address of the user.
     * @return uint256 The amount of ETH deposited by the user.
     */
    function getBalance(address _user) external view returns (uint256) {
        return deposits[_user];
    }
}
