// SPDX-License-Identifier: CC0-1.0

pragma solidity ^0.8.0;

import "./IERC3475.sol";

// This is a sample Jackrabbit Finance version of the ERC-3475 On-chain Bond Storage
contract JrtBond is IERC3475 {
    /**
     * @notice this Struct is representing the Nonce properties as an object
     */
    struct Nonce {
        mapping(uint256 => IERC3475.Values) _values;

        // stores the values corresponding to the dates (issuance and maturity date).
        mapping(address => uint256) _balances;
        mapping(address => mapping(address => uint256)) _allowances;

        // supplies of this nonce
        uint256 _activeSupply;
        uint256 _burnedSupply;
        uint256 _redeemedSupply;
    }

    /**
     * @notice this Struct is representing the Class properties as an object
     *         and can be retrieved by the classId
     */
    struct Class {
        mapping(uint256 => IERC3475.Values) _values;
        mapping(uint256 => IERC3475.Metadata) _nonceMetadatas;
        mapping(uint256 => Nonce) _nonces;
    }

    mapping(address => mapping(address => bool)) _operatorApprovals;

    // from classId given
    mapping(uint256 => Class) internal _classes;
    mapping(uint256 => IERC3475.Metadata) _classMetadata;

    /**
     * @notice Here the constructor is just to initialize a class and nonce,
     * in practice, you will have a function to create a new class and nonce
     * to be deployed during the initial deployment cycle
     */
    constructor() {
        // define "symbol of the class";
        _classMetadata[0].title = "symbol";
        _classMetadata[0]._type = "string";
        _classMetadata[0].description = "symbol of the class";
        _classes[0]._values[0].stringValue = "DBIT Fix 6M";

        _classMetadata[1].title = "symbol";
        _classMetadata[1]._type = "string";
        _classMetadata[1].description = "symbol of the class";
        _classes[1]._values[0].stringValue = "DBIT Fix test Instantaneous";

        // define "period of the class";
        _classMetadata[5].title = "period";
        _classMetadata[5]._type = "int";
        _classMetadata[5].description = "details about issuance and redemption time";

        // define the maturity time period  (for the test class).
        _classes[0]._values[5].uintValue = 10;
        _classes[1]._values[5].uintValue = 1;

        // write the time of maturity to nonce values, in other implementation, a create nonce function can be added
        _classes[0]._nonces[0]._values[0].uintValue = block.timestamp + 180 days;
        _classes[0]._nonces[1]._values[0].uintValue = block.timestamp + 181 days;
        _classes[0]._nonces[2]._values[0].uintValue = block.timestamp + 182 days;

        // test for review the instantaneous class
        _classes[1]._nonces[0]._values[0].uintValue = block.timestamp + 1;
        _classes[1]._nonces[1]._values[0].uintValue = block.timestamp + 2;
        _classes[1]._nonces[2]._values[0].uintValue = block.timestamp + 3;

        // define "maturity of the nonce";
        _classes[0]._nonceMetadatas[0].title = "maturity";
        _classes[0]._nonceMetadatas[0]._type = "int";
        _classes[0]._nonceMetadatas[0].description = "maturity date in integer";
        _classes[1]._nonceMetadatas[0].title = "maturity";
        _classes[0]._nonceMetadatas[0]._type = "int";
        _classes[1]._nonceMetadatas[0].description = "maturity date in integer";

        // defining the value status
        _classes[0]._nonces[0]._values[0].boolValue = true;
        _classes[0]._nonces[1]._values[0].boolValue = true;
        _classes[0]._nonces[2]._values[0].boolValue = true;
    }

    // WRITABLES
    function transferFrom(
        address _from,
        address _to,
        Transaction[] calldata _transactions
    ) public virtual override {
        require(
            _from != address(0),
            "JrtBond: can't transfer from the zero address"
        );
        require(
            _to != address(0),
            "JrtBond:use burn() instead"
        );
        require(
            msg.sender == _from ||
            isApprovedFor(_from, msg.sender),
            "JrtBond:caller-not-owner-or-approved"
        );
        uint256 len = _transactions.length;
        for (uint256 i = 0; i < len; i++) {
            _transferFrom(_from, _to, _transactions[i]);
        }
        emit Transfer(msg.sender, _from, _to, _transactions);
    }

    function transferAllowanceFrom(
        address _from,
        address _to,
        Transaction[] calldata _transactions
    ) public virtual override {
        require(
            _from != address(0),
            "JrtBond: can't transfer allowed amt from zero address"
        );
        require(
            _to != address(0),
            "JrtBond: use burn() instead"
        );
        uint256 len = _transactions.length;
        for (uint256 i = 0; i < len; i++) {
            require(
                _transactions[i].amount <= allowance(_from, msg.sender, _transactions[i].classId, _transactions[i].nonceId),
                "JrtBond:caller-not-owner-or-approved"
            );
            _transferAllowanceFrom(msg.sender, _from, _to, _transactions[i]);
        }
        emit Transfer(msg.sender, _from, _to, _transactions);
    }

    function issue(address _to, Transaction[] calldata _transactions)
    external
    virtual
    override
    {
        uint256 len = _transactions.length;
        for (uint256 i = 0; i < len; i++) {
            require(
                _to != address(0),
                "JrtBond: can't issue to the zero address"
            );
            _issue(_to, _transactions[i]);
        }
        emit Issue(msg.sender, _to, _transactions);
    }

    function redeem(address _from, Transaction[] calldata _transactions)
    external
    virtual
    override
    {
        require(
            _from != address(0),
            "JrtBond: can't redeem from the zero address"
        );
        uint256 len = _transactions.length;
        for (uint256 i = 0; i < len; i++) {
            (, uint256 progressRemaining) = getProgress(
                _transactions[i].classId,
                _transactions[i].nonceId
            );
            require(
                progressRemaining == 0,
                "JrtBond Error: Not redeemable"
            );
            _redeem(_from, _transactions[i]);
        }
        emit Redeem(msg.sender, _from, _transactions);
    }

    function burn(address _from, Transaction[] calldata _transactions)
    external
    virtual
    override
    {
        require(
            _from != address(0),
            "JrtBond: can't burn from the zero address"
        );
        require(
            msg.sender == _from ||
            isApprovedFor(_from, msg.sender),
            "JrtBond: caller-not-owner-or-approved"
        );
        uint256 len = _transactions.length;
        for (uint256 i = 0; i < len; i++) {
            _burn(_from, _transactions[i]);
        }
        emit Burn(msg.sender, _from, _transactions);
    }

    function approve(address _spender, Transaction[] calldata _transactions)
    external
    virtual
    override
    {
        for (uint256 i = 0; i < _transactions.length; i++) {
            _classes[_transactions[i].classId]
            ._nonces[_transactions[i].nonceId]
            ._allowances[msg.sender][_spender] = _transactions[i].amount;
        }
    }

    function setApprovalFor(
        address operator,
        bool approved
    ) public virtual override {
        _operatorApprovals[msg.sender][operator] = approved;
        emit ApprovalFor(msg.sender, operator, approved);
    }

    // READABLES
    function totalSupply(uint256 classId, uint256 nonceId)
    public
    view
    override
    returns (uint256)
    {
        return (activeSupply(classId, nonceId) +
        burnedSupply(classId, nonceId) +
        redeemedSupply(classId, nonceId)
        );
    }

    function activeSupply(uint256 classId, uint256 nonceId)
    public
    view
    override
    returns (uint256)
    {
        return _classes[classId]._nonces[nonceId]._activeSupply;
    }

    function burnedSupply(uint256 classId, uint256 nonceId)
    public
    view
    override
    returns (uint256)
    {
        return _classes[classId]._nonces[nonceId]._burnedSupply;
    }

    function redeemedSupply(uint256 classId, uint256 nonceId)
    public
    view
    override
    returns (uint256)
    {
        return _classes[classId]._nonces[nonceId]._redeemedSupply;
    }

    function balanceOf(
        address account,
        uint256 classId,
        uint256 nonceId
    ) public view override returns (uint256) {
        require(
            account != address(0),
            "JrtBond: balance query for the zero address"
        );
        return _classes[classId]._nonces[nonceId]._balances[account];
    }

    function classMetadata(uint256 metadataId)
    external
    view
    override
    returns (Metadata memory) {
        return (_classMetadata[metadataId]);
    }

    function nonceMetadata(uint256 classId, uint256 metadataId)
    external
    view
    override
    returns (Metadata memory) {
        return (_classes[classId]._nonceMetadatas[metadataId]);
    }

    function classValues(uint256 classId, uint256 metadataId)
    external
    view
    override
    returns (Values memory) {
        return (_classes[classId]._values[metadataId]);
    }


    function nonceValues(uint256 classId, uint256 nonceId, uint256 metadataId)
    external
    view
    override
    returns (Values memory) {
        return (_classes[classId]._nonces[nonceId]._values[metadataId]);
    }

    /** determines the progress till the  redemption of the bonds is valid  (based on the type of bonds class).
     * @notice ProgressAchieved and `progressRemaining` is abstract.
      For e.g. we are giving time passed and time remaining.
     */
    function getProgress(uint256 classId, uint256 nonceId)
    public
    view
    override
    returns (uint256 progressAchieved, uint256 progressRemaining){
        uint256 issuanceDate = _classes[classId]._nonces[nonceId]._values[0].uintValue;
        uint256 maturityDate = issuanceDate + _classes[classId]._nonces[nonceId]._values[5].uintValue;

        // check whether the bond is being already initialized:
        progressAchieved = block.timestamp - issuanceDate;
        progressRemaining = block.timestamp < maturityDate
        ? maturityDate - block.timestamp
        : 0;
    }
    /**
    gets the allowance of the bonds identified by (classId,nonceId) held by _owner to be spend by spender.
     */
    function allowance(
        address _owner,
        address spender,
        uint256 classId,
        uint256 nonceId
    ) public view virtual override returns (uint256) {
        return _classes[classId]._nonces[nonceId]._allowances[_owner][spender];
    }

    /**
    checks the status of approval to transfer the ownership of bonds by _owner  to operator.
     */
    function isApprovedFor(
        address _owner,
        address operator
    ) public view virtual override returns (bool) {
        return _operatorApprovals[_owner][operator];
    }

    // INTERNALS
    function _transferFrom(
        address _from,
        address _to,
        IERC3475.Transaction calldata _transaction
    ) private {
        Nonce storage nonce = _classes[_transaction.classId]._nonces[_transaction.nonceId];
        require(
            nonce._balances[_from] >= _transaction.amount,
            "JrtBond: not enough bond to transfer"
        );

        //transfer balance
        nonce._balances[_from] -= _transaction.amount;
        nonce._balances[_to] += _transaction.amount;
    }

    function _transferAllowanceFrom(
        address _operator,
        address _from,
        address _to,
        IERC3475.Transaction calldata _transaction
    ) private {
        Nonce storage nonce = _classes[_transaction.classId]._nonces[_transaction.nonceId];
        require(
            nonce._balances[_from] >= _transaction.amount,
            "JrtBond: not allowed amount"
        );
        // reducing the allowance and decreasing accordingly.
        nonce._allowances[_from][_operator] -= _transaction.amount;

        //transfer balance
        nonce._balances[_from] -= _transaction.amount;
        nonce._balances[_to] += _transaction.amount;
    }

    function _issue(
        address _to,
        IERC3475.Transaction calldata _transaction
    ) private {
        Nonce storage nonce = _classes[_transaction.classId]._nonces[_transaction.nonceId];

        //transfer balance
        nonce._balances[_to] += _transaction.amount;
        nonce._activeSupply += _transaction.amount;
    }


    function _redeem(
        address _from,
        IERC3475.Transaction calldata _transaction
    ) private {
        Nonce storage nonce = _classes[_transaction.classId]._nonces[_transaction.nonceId];
        // verify whether _amount of bonds to be redeemed  are sufficient available  for the given nonce of the bonds

        require(
            nonce._balances[_from] >= _transaction.amount,
            "JrtBond: not enough bond to transfer"
        );

        //transfer balance
        nonce._balances[_from] -= _transaction.amount;
        nonce._activeSupply -= _transaction.amount;
        nonce._redeemedSupply += _transaction.amount;
    }


    function _burn(
        address _from,
        IERC3475.Transaction calldata _transaction
    ) private {
        Nonce storage nonce = _classes[_transaction.classId]._nonces[_transaction.nonceId];
        // verify whether _amount of bonds to be burned are sfficient available for the given nonce of the bonds
        require(
            nonce._balances[_from] >= _transaction.amount,
            "Jrt: not enough bond to transfer"
        );

        //transfer balance
        nonce._balances[_from] -= _transaction.amount;
        nonce._activeSupply -= _transaction.amount;
        nonce._burnedSupply += _transaction.amount;
    }

}
