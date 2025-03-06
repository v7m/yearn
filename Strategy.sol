// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Vault.sol";

// Для примера
interface IExternalProtocol {
    /// Переводит средства во внешний протокол (депозит)
    function deposit(uint256 amount) external;
    /// Выводит средства из внешнего протокола
    function withdraw(uint256 amount) external;
    /// Возвращает текущий баланс с начисленными процентами
    function getCurrentBalance() external view returns (uint256);
    function estimatedYield() external view returns (uint256);
}

contract Strategy is IStrategy {
    IERC20 public token;  // Токен, которым оперирует стратегия
    address public vault; // Адрес Vault, откуда поступают инвестиции

    IExternalProtocol public externalProtocol; // Адрес внешнего протокола, в который инвестируются средства

    uint256 public investedAmount; // Сумма инвестированных средств

    /// Конструктор задаёт адрес токена и адрес Vault
    constructor(address _token, address _vault, address _externalProtocol) {
        token = IERC20(_token);
        vault = _vault;
        investedAmount = 0;
        externalProtocol = IExternalProtocol(_externalProtocol);
    }

    /// Функция для инвестирования средств. Вызывается только из Vault.
    function invest(uint256 amount) external override {
        require(msg.sender == vault, "Only vault can invest");
        // Перевод токенов из Vault в стратегию
        require(token.transferFrom(vault, address(this), amount), "Transfer failed");
        investedAmount += amount;

        // Логика инвестирования средств в конкретный протокол
    }

    /// Функция для вывода средств. Вызывается только из Vault.
    function withdraw(uint256 amount) external override {
        require(msg.sender == vault, "Only vault can withdraw");
        // Выводим средства из внешнего протокола
        externalProtocol.withdraw(amount);
        // Переводим выведенные токены обратно в Vault
        require(token.transfer(vault, amount), "Transfer failed");
        // Обновляем сумму инвестированных средств
        investedAmount = amount > investedAmount ? 0 : investedAmount - amount;
    }

    /// Возвращает текущий баланс инвестированных средств
    function balance() external view override returns (uint256) {
        return externalProtocol.getCurrentBalance(); // Получение текущего баланса из внешнего протокола (с начисленными процентами)
    }

    /// Возвращает оценочную доходность стратегии, расчитывается для каждой стратегии по-разному
    function estimatedYield() external view override returns (uint256) {
        return externalProtocol.estimatedYield(); // Получение оценки доходности из внешнего протокола
    }
}