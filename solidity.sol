// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Decentralized Identity Verification
 * @dev A smart contract for creating and managing decentralized identities
 * @author DID Team
 */
contract Project {
    
    // Struct to represent a digital identity
    struct Identity {
        address owner;
        string name;
        string email;
        uint256 createdAt;
        bool isVerified;
        mapping(string => string) attributes; // Additional attributes like phone, address, etc.
        mapping(address => bool) verifiers; // Addresses that can verify this identity
    }
    
    // Struct to represent a credential/claim
    struct Credential {
        uint256 id;
        address issuer;
        address subject;
        string credentialType; // e.g., "education", "employment", "certification"
        string data; // IPFS hash or encrypted data
        uint256 issuedAt;
        uint256 expiresAt;
        bool isValid;
    }
    
    // State variables
    mapping(address => Identity) public identities;
    mapping(uint256 => Credential) public credentials;
    mapping(address => bool) public authorizedVerifiers;
    
    uint256 private credentialCounter;
    address public admin;
    
    // Events
    event IdentityCreated(address indexed user, string name, uint256 timestamp);
    event IdentityVerified(address indexed user, address indexed verifier, uint256 timestamp);
    event CredentialIssued(uint256 indexed credentialId, address indexed issuer, address indexed subject, string credentialType);
    event CredentialRevoked(uint256 indexed credentialId, address indexed issuer);
    event VerifierAuthorized(address indexed verifier, address indexed admin);
    
    // Modifiers
    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can perform this action");
        _;
    }
    
    modifier onlyAuthorizedVerifier() {
        require(authorizedVerifiers[msg.sender], "Not an authorized verifier");
        _;
    }
    
    modifier identityExists(address user) {
        require(identities[user].owner != address(0), "Identity does not exist");
        _;
    }
    
    constructor() {
        admin = msg.sender;
        authorizedVerifiers[msg.sender] = true; // Admin is also a verifier
    }
    
    /**
     * @dev Core Function 1: Create a new decentralized identity
     * @param _name Full name of the identity holder
     * @param _email Email address of the identity holder
     */
    function createIdentity(string memory _name, string memory _email) external {
        require(identities[msg.sender].owner == address(0), "Identity already exists for this address");
        require(bytes(_name).length > 0, "Name cannot be empty");
        require(bytes(_email).length > 0, "Email cannot be empty");
        
        Identity storage newIdentity = identities[msg.sender];
        newIdentity.owner = msg.sender;
        newIdentity.name = _name;
        newIdentity.email = _email;
        newIdentity.createdAt = block.timestamp;
        newIdentity.isVerified = false;
        
        emit IdentityCreated(msg.sender, _name, block.timestamp);
    }
    
    /**
     * @dev Core Function 2: Issue a verifiable credential to an identity
     * @param _subject Address of the identity receiving the credential
     * @param _credentialType Type of credential (e.g., "education", "employment")
     * @param _data IPFS hash or encrypted credential data
     * @param _expirationDuration Duration in seconds until credential expires
     */
    function issueCredential(
        address _subject,
        string memory _credentialType,
        string memory _data,
        uint256 _expirationDuration
    ) external onlyAuthorizedVerifier identityExists(_subject) returns (uint256) {
        require(bytes(_credentialType).length > 0, "Credential type cannot be empty");
        require(bytes(_data).length > 0, "Credential data cannot be empty");
        
        credentialCounter++;
        uint256 credentialId = credentialCounter;
        
        Credential storage newCredential = credentials[credentialId];
        newCredential.id = credentialId;
        newCredential.issuer = msg.sender;
        newCredential.subject = _subject;
        newCredential.credentialType = _credentialType;
        newCredential.data = _data;
        newCredential.issuedAt = block.timestamp;
        newCredential.expiresAt = block.timestamp + _expirationDuration;
        newCredential.isValid = true;
        
        emit CredentialIssued(credentialId, msg.sender, _subject, _credentialType);
        return credentialId;
    }
    
    /**
     * @dev Core Function 3: Verify an identity or credential
     * @param _user Address of the identity to verify
     * @param _credentialId Optional credential ID to verify (0 for general identity verification)
     */
    function verifyIdentity(address _user, uint256 _credentialId) external onlyAuthorizedVerifier identityExists(_user) returns (bool) {
        Identity storage identity = identities[_user];
        
        if (_credentialId == 0) {
            // General identity verification
            identity.isVerified = true;
            identity.verifiers[msg.sender] = true;
            emit IdentityVerified(_user, msg.sender, block.timestamp);
            return true;
        } else {
            // Specific credential verification
            require(credentials[_credentialId].subject == _user, "Credential does not belong to this user");
            require(credentials[_credentialId].isValid, "Credential is not valid");
            require(block.timestamp <= credentials[_credentialId].expiresAt, "Credential has expired");
            
            return true;
        }
    }
    
    // Additional utility functions
    
    /**
     * @dev Add an authorized verifier (only admin)
     */
    function addVerifier(address _verifier) external onlyAdmin {
        authorizedVerifiers[_verifier] = true;
        emit VerifierAuthorized(_verifier, msg.sender);
    }
    
    /**
     * @dev Revoke a credential (only issuer can revoke)
     */
    function revokeCredential(uint256 _credentialId) external {
        require(credentials[_credentialId].issuer == msg.sender, "Only issuer can revoke credential");
        credentials[_credentialId].isValid = false;
        emit CredentialRevoked(_credentialId, msg.sender);
    }
    
    /**
     * @dev Get identity information
     */
    function getIdentity(address _user) external view returns (
        string memory name,
        string memory email,
        uint256 createdAt,
        bool isVerified
    ) {
        Identity storage identity = identities[_user];
        return (identity.name, identity.email, identity.createdAt, identity.isVerified);
    }
    
    /**
     * @dev Get credential information
     */
    function getCredential(uint256 _credentialId) external view returns (
        address issuer,
        address subject,
        string memory credentialType,
        string memory data,
        uint256 issuedAt,
        uint256 expiresAt,
        bool isValid
    ) {
        Credential storage cred = credentials[_credentialId];
        return (
            cred.issuer,
            cred.subject,
            cred.credentialType,
            cred.data,
            cred.issuedAt,
            cred.expiresAt,
            cred.isValid
        );
    }
    
    /**
     * @dev Check if an address is an authorized verifier
     */
    function isAuthorizedVerifier(address _verifier) external view returns (bool) {
        return authorizedVerifiers[_verifier];
    }
    
    /**
     * @dev Get total number of credentials issued
     */
    function getTotalCredentials() external view returns (uint256) {
        return credentialCounter;
    }
}