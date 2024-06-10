pragma solidity ^0.5.0;

contract ERC20 is Context, IERC20 {
    using SafeMath for uint256; // SafeMath 라이브러리를 사용하여 산술 연산의 안전성을 보장합니다.

    // 각 주소의 잔액을 저장하는 매핑
    mapping (address => uint256) private _balances;

    // 각 주소의 허용량을 저장하는 매핑 (소유자 => (스펜더 => 허용량))
    mapping (address => mapping (address => uint256)) private _allowances;

    // 전체 토큰 공급량
    uint256 private _totalSupply;

     // 전체 토큰 공급량을 반환합니다.

    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

     // 주어진 계정의 토큰 잔액을 반환합니다.
    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    
    // 특정 계정에게 토큰을 전송합니다.
    function transfer(address recipient, uint256 amount) public returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }


     //특정 소유자가 특정 스펜더에게 허용한 토큰 양을 반환합니다.
    function allowance(address owner, address spender) public view returns (uint256) {
        return _allowances[owner][spender];
    }

     // 특정 스펜더가 호출자의 토큰을 사용할 수 있는 허용량을 설정합니다.

    function approve(address spender, uint256 amount) public returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }


     // 특정 계정에서 다른 계정으로 토큰을 전송합니다.

    function transferFrom(address sender, address recipient, uint256 amount) public returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount, "ERC20: transfer amount exceeds allowance"));
        return true;
    }

     //@dev 호출자가 특정 스펜더에게 허용한 토큰 양을 증가시킵니다.
    function increaseAllowance(address spender, uint256 addedValue) public returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].add(addedValue));
        return true;
    }

    // 호출자가 특정 스펜더에게 허용한 토큰 양을 감소시킵니다.
     
    function decreaseAllowance(address spender, uint256 subtractedValue) public returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].sub(subtractedValue, "ERC20: decreased allowance below zero"));
        return true;
    }

    // 내부 함수로, `sender`에서 `recipient`로 토큰을 이동합니다.
     
    function _transfer(address sender, address recipient, uint256 amount) internal {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        // SafeMath를 사용하여 잔액을 안전하게 감소 및 증가시킵니다.
        _balances[sender] = _balances[sender].sub(amount, "ERC20: transfer amount exceeds balance");
        _balances[recipient] = _balances[recipient].add(amount);
        emit Transfer(sender, recipient, amount); // Transfer 이벤트를 발생시킵니다.
    }


     // 총 공급량을 증가시킵니다.
    
    function _mint(address account, uint256 amount) internal {
        require(account != address(0), "ERC20: mint to the zero address");

        // SafeMath를 사용하여 총 공급량 및 계정 잔액을 안전하게 증가시킵니다.
        _totalSupply = _totalSupply.add(amount);
        _balances[account] = _balances[account].add(amount);
        emit Transfer(address(0), account, amount); // Transfer 이벤트를 발생시킵니다.
    }

    
     //   `account`로부터 `amount`만큼의 토큰을 소각하여 총 공급량을 감소시킵니다.
     
    function _burn(address account, uint256 amount) internal {
        require(account != address(0), "ERC20: burn from the zero address");

        // SafeMath를 사용하여 잔액을 안전하게 감소시키고 총 공급량을 감소시킵니다.
        _balances[account] = _balances[account].sub(amount, "ERC20: burn amount exceeds balance");
        _totalSupply = _totalSupply.sub(amount);
        emit Transfer(account, address(0), amount); // Transfer 이벤트를 발생시킵니다.
    }

    // `owner`의 토큰을 `spender`가 사용할 수 있는 허용량을 설정합니다.

    function _approve(address owner, address spender, uint256 amount) internal {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount; // 허용량을 설정합니다.
        emit Approval(owner, spender, amount); // Approval 이벤트를 발생시킵니다.
    }

    // `account`의 토큰을 소각하여 총 공급량을 감소시키고,호출자의 허용량에서 `amount`를 차감합니다.

    function _burnFrom(address account, uint256 amount) internal {
        _burn(account, amount); // 계정의 토큰을 소각합니다.
        _approve(account, _msgSender(), _allowances[account][_msgSender()].sub(amount, "ERC20: burn amount exceeds allowance")); // 호출자의 허용량에서 amount를 차감합니다.
    }
}
