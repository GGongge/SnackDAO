pragma solidity ^0.8.13;

contract MultiSigWallet {
    // 이벤트

    event Confirmation(address indexed sender, uint indexed transactionId); // 소유자가 거래를 확인할 때 트리거되는 이벤트.
    event Revocation(address indexed sender, uint indexed transactionId); // 소유자가 확인을 철회할 때 트리거되는 이벤트.
    event Submission(uint indexed transactionId); // 새로운 거래가 제출될 때 트리거되는 이벤트.
    event Execution(uint indexed transactionId); // 거래가 실행될 때 트리거되는 이벤트.
    event ExecutionFailure(uint indexed transactionId); // 거래 실행이 실패할 때 트리거되는 이벤트.
    event Deposit(address indexed sender, uint value); // 이더가 입금될 때 트리거되는 이벤트.
    event OwnerAddition(address indexed owner); // 새로운 소유자가 추가될 때 트리거되는 이벤트.
    event OwnerRemoval(address indexed owner); // 소유자가 제거될 때 트리거되는 이벤트.
    event RequirementChange(uint required); // 필요한 확인 수가 변경될 때 트리거되는 이벤트.

    uint constant public MAX_OWNER_COUNT = 50; // 허용되는 최대 소유자 수.

    mapping (uint => Transaction) public transactions; // 거래 ID와 거래 세부 정보를 매핑.
    mapping (uint => mapping (address => bool)) public confirmations; // 거래 ID와 소유자 주소 및 확인 상태를 매핑.
    mapping (address => bool) public isOwner; // 주소가 소유자인지 확인하는 매핑.
    address[] public owners; // 소유자 주소 배열.
    uint public required; // 거래에 필요한 확인 수.
    uint public transactionCount; // 총 거래 수.

    struct Transaction {
        address destination; // 거래가 보내질 주소.
        uint value; // 거래의 이더 값.
        bytes data; // 거래의 데이터 페이로드.
        bool executed; // 거래가 실행되었는지 여부.
    }

    /*
    *  제약 조건
    */
    modifier onlyWallet() {
        require(msg.sender == address(this), "MultisigWallet: address is not a multisig wallet");
        _; // 함수가 지갑 자체에 의해서만 호출되도록 보장합니다.
    }

    modifier ownerDoesNotExist(address owner) {
        require(!isOwner[owner], "MultisigWallet: address exists in owner addresses list");
        _; // 소유자가 이미 존재하지 않도록 보장합니다.
    }

    modifier ownerExists(address owner) {
        require(isOwner[owner], "MultisigWallet: address not exists in owner addresses list");
        _; // 소유자가 존재하도록 보장합니다.
    }

    modifier transactionExists(uint transactionId) {
        require(transactions[transactionId].destination != address(0), "MultisigWallet: transaction does not exist");
        _; // 거래가 존재하도록 보장합니다.
    }

    modifier confirmed(uint transactionId, address owner) {
        require(confirmations[transactionId][owner], "MultisigWallet: transaction is not confirmed");
        _; // 거래가 소유자에 의해 확인되도록 보장합니다.
    }

    modifier notConfirmed(uint transactionId, address owner) {
        require(!confirmations[transactionId][owner], "MultisigWallet: transaction is confirmed");
        _; // 거래가 소유자에 의해 아직 확인되지 않도록 보장합니다.
    }

    modifier notExecuted(uint transactionId) {
        require(!transactions[transactionId].executed, "MultisigWallet: transaction is executed before");
        _; // 거래가 아직 실행되지 않도록 보장합니다.
    }

    modifier notNull(address _address) {
        require(_address != address(0), "MultisigWallet: address is null");
        _; // 주소가 null이 아니도록 보장합니다.
    }

    modifier validRequirement(uint ownerCount, uint _required) {
        require(
            ownerCount <= MAX_OWNER_COUNT
            && _required <= ownerCount
            && _required != 0
            && ownerCount != 0
            , "MultisigWallet: owner requirement is not valid");
        _; // 소유자의 요구 사항이 유효하도록 보장합니다.
    }

    /// 폴백 함수는 이더 입금을 허용합니다.
    receive() external payable {
        if (msg.value > 0)
            emit Deposit(msg.sender, msg.value);
    }

    /// 계약 생성자는 초기 소유자와 필요한 확인 수를 설정합니다.
    constructor(address[] memory _owners, uint _required)
        validRequirement(_owners.length, _required)
    {
        for (uint i = 0; i < _owners.length; i++) {
            require(!isOwner[_owners[i]] && _owners[i] != address(0));
            isOwner[_owners[i]] = true;
        }
        owners = _owners;
        required = _required;
    }

    /// 새로운 소유자를 추가할 수 있습니다. 
    function addOwner(address owner)
        public
        onlyWallet
        ownerDoesNotExist(owner)
        notNull(owner)
        validRequirement(owners.length + 1, required)
    {
        isOwner[owner] = true;
        owners.push(owner);
        emit OwnerAddition(owner);
    }

    /// 소유자를 제거할 수 있습니다.
    function removeOwner(address owner)
        public
        onlyWallet
        ownerExists(owner)
    {
        isOwner[owner] = false;
        for (uint256 i = 0; i < owners.length; i++)
            if (owners[i] == owner) {
                owners[i] = owners[owners.length - 1];
                owners.pop();
                break;
            }

        if (required > owners.length)
            changeRequirement(owners.length);
        emit OwnerRemoval(owner);
    }

    /// 소유자를 새로운 소유자로 교체할 수 있습니다.
    function replaceOwner(address owner, address newOwner)
        public
        onlyWallet
        ownerExists(owner)
        ownerDoesNotExist(newOwner)
    {
        for (uint i = 0; i < owners.length; i++)
            if (owners[i] == owner) {
                owners[i] = newOwner;
                break;
            }
        isOwner[owner] = false;
        isOwner[newOwner] = true;
        emit OwnerRemoval(owner);
        emit OwnerAddition(newOwner);
    }

    /// 필요한 확인 수를 변경할 수 있습니다.
    function changeRequirement(uint _required)
        public
        onlyWallet
        validRequirement(owners.length, _required)
    {
        required = _required;
        emit RequirementChange(_required);
    }

    /// 소유자가 거래를 제출하고 확인할 수 있습니다.
    function submitTransaction(address destination, uint value, bytes memory data)
        public
        returns (uint transactionId)
    {
        transactionId = addTransaction(destination, value, data);
        confirmTransaction(transactionId);
    }

    ///소유자가 거래를 확인할 수 있습니다.
    function confirmTransaction(uint transactionId)
        public
        ownerExists(msg.sender)
        transactionExists(transactionId)
        notConfirmed(transactionId, msg.sender)
    {
        confirmations[transactionId][msg.sender] = true;
        emit Confirmation(msg.sender, transactionId);
        executeTransaction(transactionId);
    }

    /// 소유자가 거래에 대한 확인을 철회할 수 있습니다.
    function revokeConfirmation(uint transactionId)
        public
        ownerExists(msg.sender)
        confirmed(transactionId, msg.sender)
        notExecuted(transactionId)
    {
        confirmations[transactionId][msg.sender] = false;
        emit Revocation(msg.sender, transactionId);
    }

    /// 누구나 확인된 거래를 실행할 수 있습니다.
    function executeTransaction(uint transactionId)
        public
        ownerExists(msg.sender)
        confirmed(transactionId, msg.sender)
        notExecuted(transactionId)
    {
        if (isConfirmed(transactionId)) {
            Transaction storage txn = transactions[transactionId];
            txn.executed = true;
            if (external_call(txn.destination, txn.value, txn.data.length, txn.data))
                emit Execution(transactionId);
            else {
                emit ExecutionFailure(transactionId);
                txn.executed = false;
            }
        }
    }

    // 호출은 자체 함수로 분리되어, 솔리디티의 코드 생성기를 활용하여 tx.data를 메모리에 올립니다.
    function external_call(address destination, uint value, uint dataLength, bytes memory data) internal returns (bool) {
        bool result;
        assembly { // 어셈블리어를 사용하여 직접 호출
            let x := mload(0x40)   // 메모리에서 여유 공간을 가져옴
            let d := add(data, 32) // 데이터의 시작 위치

            result := call(
                sub(gas(), 34710),   // 남은 가스를 계산하여 설정
                destination,
                value,
                d,
                dataLength,        // 입력 크기 (바이트 단위)
                x,
                0                  // 출력은 무시되므로 출력 크기는 0
            )
        }
        return result;
    }

    /// 거래의 확인 상태를 반환합니다.
    function isConfirmed(uint transactionId)
        public
        view
        returns (bool)
    {
        uint count = 0;
        for (uint i=0; i<owners.length; i++) {
            if (confirmations[transactionId][owners[i]])
                count += 1;
            if (count == required)
                return true;
        }
        return false;
    }

    /// 거래가 아직 존재하지 않는 경우 거래 매핑에 새로운 거래를 추가합니다.
    function addTransaction(address destination, uint value, bytes memory data)
        internal
        notNull(destination)
        returns (uint transactionId)
    {
        transactionId = transactionCount;
        transactions[transactionId] = Transaction({
            destination: destination,
            value: value,
            data: data,
            executed: false
        });
        transactionCount += 1;
        emit Submission(transactionId);
    }

    /// 거래의 확인 수를 반환합니다.

    function getConfirmationCount(uint transactionId)
        public
        view
        returns (uint count)
    {
        for (uint i=0; i<owners.length; i++)
            if (confirmations[transactionId][owners[i]])
                count += 1;
    }

    /// 필터가 적용된 후 거래의 총 수를 반환합니다.
    function getTransactionCount(bool pending, bool executed)
        public
        view
        returns (uint count)
    {
        for (uint i=0; i<transactionCount; i++)
            if (   pending && !transactions[i].executed
                || executed && transactions[i].executed)
                count += 1;
    }

    /// 소유자 목록을 반환합니다.
    function getOwners()
        public
        view
        returns (address[] memory)
    {
        return owners;
    }

    /// 거래를 확인한 소유자 주소 배열을 반환합니다.
    function getConfirmations(uint transactionId)
        public
        view
        returns (address[] memory _confirmations)
    {
        address[] memory confirmationsTemp = new address[](owners.length);
        uint count = 0;
        uint i;
        for (i=0; i<owners.length; i++)
            if (confirmations[transactionId][owners[i]]) {
                confirmationsTemp[count] = owners[i];
                count += 1;
            }
        _confirmations = new address[](count);
        for (i=0; i<count; i++)
            _confirmations[i] = confirmationsTemp[i];
    }

    /// 정의된 범위 내에서 거래 ID 목록을 반환합니다.
    function getTransactionIds(uint from, uint to, bool pending, bool executed)
        public
        view
        returns (uint[] memory _transactionIds)
    {
        uint[] memory transactionIdsTemp = new uint[](transactionCount);
        uint count = 0;
        uint i;
        for (i=0; i<transactionCount; i++)
            if (   pending && !transactions[i].executed
                || executed && transactions[i].executed)
            {
                transactionIdsTemp[count] = i;
                count += 1;
            }
        _transactionIds = new uint[](to - from);
        for (i=from; i<to; i++)
            _transactionIds[i - from] = transactionIdsTemp[i];
    }
}
