// SPDX-License-Identifier: MIT
pragma solidity ^0.7.5;

contract MultiSig {
    address[] public owners;
    uint public required;
    mapping (uint256 => Transaction) public transactions;
    uint256 public transactionCount;
    mapping (uint256 => mapping (address => bool)) public confirmations;

    struct Transaction {
        address destination;
        uint256 value;
        bool executed;
        bytes data;
    }

    constructor(address[] memory _owners, uint256 _confirmations) {
        require(_owners.length > 0);
        require(_confirmations > 0);
        require(_owners.length >= _confirmations);

        owners = _owners;
        required = _confirmations; 
    }

    function getTransactionCount(bool pending, bool executed) public view returns(uint _transactionCount) {
        for (uint i = 0; i < transactionCount; i++) {
            if (
                pending && executed
                || pending && transactions[i].executed == false 
                || executed && transactions[i].executed == true
            ) {
                 _transactionCount++;   
            }
        }
    }

    function getTransactionIds(bool pending, bool executed) public view returns(uint256[] memory) {
        uint256 _transactionCount = getTransactionCount(pending, executed);
        uint256[] memory transactionIds = new uint256[](_transactionCount);
        uint256 transactionCounter = 0;

        for (uint256 i = 0; i < transactionCount; i++) {
            if (
                pending && executed
                || pending && transactions[i].executed == false 
                || executed && transactions[i].executed == true
            ) {
                transactionIds[transactionCounter] = i;
                transactionCounter++;
            } 
        }

        return transactionIds;
    }

    function getOwners() external view returns(address[] memory _owners) {
        _owners = owners;
    }

    function addTransaction(address destination, uint256 value, bytes memory data) internal returns (uint256 transactionId) {
        transactionId = transactionCount;
        transactions[transactionId] = Transaction(destination, value, false, data);
        transactionCount++;
    }

    function confirmTransaction(uint256 transactionId) public {
        bool canConfirm = false;
        for (uint i = 0; i < owners.length; i++) {
            if(owners[i] == msg.sender) {
                canConfirm = true;
                break;
            }
        }

        require(canConfirm);
        confirmations[transactionId][msg.sender] = true;

        if(getConfirmationsCount(transactionId) < required) {
            return;
        }

        executeTransaction(transactionId);
    }

    function getConfirmationsCount(uint256 transactionId) public view returns (uint256 confirmationCount) {
        for (uint256 i = 0; i < owners.length; i++) {
            if(confirmations[transactionId][owners[i]]) {
                confirmationCount++;
            }
        }
    }

    function getConfirmations(uint256 transactionId) external view returns (address[] memory) {
        uint256 confirmationCount = getConfirmationsCount(transactionId);
        address[] memory confirmers = new address[](confirmationCount);
        uint256 confirmerIndex = 0;

        for (uint256 i = 0; i < owners.length; i++) {
            if(confirmations[transactionId][owners[i]]) {
                confirmers[confirmerIndex] = owners[i];
                confirmerIndex++;
            }
        }

        return confirmers;
    }

    function submitTransaction(address destination, uint256 value, bytes memory data) external {
        addTransaction(destination, value, data);
        confirmTransaction(transactionCount - 1);
    }

    function isConfirmed(uint256 transactionId) public view returns(bool _isConfirmed) {
        return getConfirmationsCount(transactionId) >= required;
    }

    function executeTransaction(uint256 transactionId) public {
        require(isConfirmed(transactionId));
    
        Transaction storage _tx = transactions[transactionId];

        _tx.executed = true;
        (bool success, ) = _tx.destination.call{ value: _tx.value }(_tx.data);
        require(success, "Failed to execute transaction");
    }

    receive() external payable {}
}
