pragma solidity ^0.5.0;

import "../GSN/Context.sol";
import "../token/ERC20/ERC20.sol";
import "../token/ERC20/ERC20Detailed.sol";

contract SimpleToken is Context, ERC20, ERC20Detailed {

// 토큰 이름, 심볼, 소수점 자릿수를 설정하고, 생성자에게 초기 토큰을 할당합니다.
    constructor () public ERC20Detailed("BaekseokUniversityToken", "BUT", 0) {
        // 초기 토큰 공급량을 설정하고, _msgSender()에게 모든 토큰을 할당합니다.
        // 여기서는 10000개의 토큰을 생성하고, 소수점 자릿수는 0으로 설정합니다.
        _mint(_msgSender(), 10000 * (10 ** uint256(decimals())));
    }
}
