// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract ModelRegistry {
    struct Model {
        // Hugging Face format: user-name/model-name
        // Must be lowercase
        string name;
        // IPFS hash of the model
        string ipfsHash;
    }

    // Mapping from model names to their details
    mapping(string => Model) private _models;

    // Event emitted when a new model is registered
    event ModelRegistered(string indexed name, string ipfsHash);

    /**
     * @dev Registers a new model with the given name and IPFS hash.
     * Emits a ModelRegistered event upon success.
     * Reverts if the model name is already registered.
     * @param _name The name of the model to register, following the Hugging Face format. Must be lowercase.
     * @param _ipfsHash The IPFS hash of the model.
     */
    function registerModel(string memory _name, string memory _ipfsHash) public {
        // Require that the model has not been registered before
        require(keccak256(abi.encodePacked(_models[_name].name)) == keccak256(abi.encodePacked("")), "Model already registered");

        // Store the model details
        _models[_name] = Model(_name, _ipfsHash);

        // Emit the event
        emit ModelRegistered(_name, _ipfsHash);
    }

    /**
     * @dev Retrieves the details of a registered model by its name.
     * Reverts if the model name is not registered.
     * @param _name The name of the model to retrieve details for.
     * @return Model Returns the Model struct containing the name and IPFS hash of the model.
     */
    function getModelDetails(string memory _name) public view returns (Model memory) {
        require(keccak256(abi.encodePacked(_models[_name].name)) != keccak256(abi.encodePacked("")), "Model not registered");
        return _models[_name];
    }
}

