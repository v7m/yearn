// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

interface IStrategy {
    /// Инвестирует указанную сумму токенов
    function invest(uint256 amount) external;
    /// Выводит указанную сумму токенов из стратегии
    function withdraw(uint256 amount) external;
    /// Возвращает баланс средств, инвестированных в стратегию
    function balance() external view returns (uint256);
    /// Возвращает оценку доходности стратегии
    function estimatedYield() external view returns (uint256);
}

/// Vault принимает депозиты пользователей и распределяет их по стратегиям
/// Один Vault может содержать несколько стратегий, но использоваться может только одна в каждый момент времени
/// Каждый Vault предполагает работу с одним токеном
contract Vault {
    IERC20 public token;           // ERC20 токен, которым оперирует Vault
    address public owner;          // Адрес владельца, имеющий административные права

    IStrategy[] public strategies; // Массив зарегистрированных стратегий

    uint256 public totalShares;                    // Общее количество выпущенных долей
    mapping(address => uint256) public shares;     // Доли каждого пользователя

    uint256 public activeStrategyIndex; // Индекс текущей активной стратегии

    event Deposit(address indexed user, uint256 amount, uint256 sharesMinted);
    event Withdraw(address indexed user, uint256 amount, uint256 sharesBurned);
    event Rebalanced(uint256 totalRebalanced, uint256 newActiveStrategyIndex);

    modifier onlyOwner() {
        require(msg.sender == owner, "Vault: Not owner");
        _;
    }

    /// Инициализация Vault с адресом токена
    constructor(address _token) {
        token = IERC20(_token);
        owner = msg.sender;
        activeStrategyIndex = 0;
    }

    /// Добавление новой стратегии (только для владельца контракта)
    function addStrategy(IStrategy _strategy) external onlyOwner {
        strategies.push(_strategy);
        // Если добавляется первая стратегия, назначаем её активной
        if (strategies.length == 1) {
            activeStrategyIndex = 0;
        }
    }

    /// Возвращает общий баланс Vault, включая токены на контракте и средства, инвестированные в стратегии
    function totalVaultBalance() public view returns (uint256 totalBalance) {
        totalBalance = token.balanceOf(address(this));
        for (uint256 i = 0; i < strategies.length; i++) {
            totalBalance += strategies[i].balance();
        }
    }

    /// При депозите рассчитываются новые доли для вкладчика, не затрагивая уже существующие.
    function deposit(uint256 amount) external {
        require(amount > 0, "Vault: Amount must be > 0");
        require(token.transferFrom(msg.sender, address(this), amount), "Vault: Transfer failed");
        
        // Рассчитываем общий баланс Vault ДО депозита (без только что переведенных средств)
        uint256 vaultBalanceBefore = totalVaultBalance() - amount;
        uint256 mintedShares;
        if (totalShares == 0 || vaultBalanceBefore == 0) {
            mintedShares = amount; // Если Vault пуст, выдаем доли 1:1
        } else {
            mintedShares = (amount * totalShares) / vaultBalanceBefore;
        }
        totalShares += mintedShares;
        shares[msg.sender] += mintedShares;
        
        emit Deposit(msg.sender, amount, mintedShares);
        
        // Автоматическая аллокация средств в стратегию с наивысшей доходностью
        allocateFunds(amount);
    }

    // Внутренняя функция для распределения средств по стратегиям.
    /// Выбирается стратегия с наивысшей оценкой доходности, и обновляется activeStrategyIndex.
    function allocateFunds(uint256 amount) internal {
        require(strategies.length > 0, "Vault: No strategies available");
        uint256 bestYield = 0;
        uint256 bestIndex = activeStrategyIndex;

        // Определяем стратегию с наивысшей оценкой доходности
        for (uint256 i = 0; i < strategies.length; i++) {
            uint256 currentYield = strategies[i].estimatedYield();
            if (currentYield > bestYield) {
                bestYield = currentYield;
                bestIndex = i;
            }
        }
        activeStrategyIndex = bestIndex;
        // Инвестируем средства в выбранную стратегию
        require(token.approve(address(strategies[bestIndex]), amount), "Vault: Approve failed");
        strategies[bestIndex].invest(amount);
    }

    /// Ребалансировка – перевод средств из менее эффективных стратегий в стратегию с наивысшей доходностью.
    /// Вызывается владельцем или внешними keeper-ботами.
    function rebalance() external onlyOwner {
        require(strategies.length > 0, "Vault: No strategies available");
        uint256 bestYield = 0;
        uint256 bestIndex = activeStrategyIndex;
        // Определяем стратегию с наивысшей оценкой доходности
        for (uint256 i = 0; i < strategies.length; i++) {
            uint256 currentYield = strategies[i].estimatedYield();
            if (currentYield > bestYield) {
                bestYield = currentYield;
                bestIndex = i;
            }
        }

        uint256 totalRebalanced = 0;
        // Вывод средств из всех стратегий, кроме выбранной лучшей
        for (uint256 i = 0; i < strategies.length; i++) {
            if (i != bestIndex) {
                uint256 funds = strategies[i].balance();
                if (funds > 0) {
                    strategies[i].withdraw(funds);
                    totalRebalanced += funds;
                }
            }
        }
        // Если активная стратегия отличается от лучшей, выводим и её средства
        if (activeStrategyIndex != bestIndex) {
            uint256 funds = strategies[activeStrategyIndex].balance();
            if (funds > 0) {
                strategies[activeStrategyIndex].withdraw(funds);
                totalRebalanced += funds;
            }
        }
        // Реинвестируем все выведенные средства в стратегию с наивысшей доходностью
        if (totalRebalanced > 0) {
            require(token.approve(address(strategies[bestIndex]), totalRebalanced), "Vault: Approve failed");
            strategies[bestIndex].invest(totalRebalanced);
        }
        activeStrategyIndex = bestIndex;
        emit Rebalanced(totalRebalanced, bestIndex);
    }

    /// Функция вывода средств.
    /// Пользователь сжигает указанное количество долей и получает обратно сумму,
    /// пропорциональную его участию в общем балансе Vault (депозит + проценты).
    function withdraw(uint256 shareAmount) external {
        require(shares[msg.sender] >= shareAmount, "Vault: Insufficient shares");

        // Текущий общий баланс Vault
        uint256 totalBalance = totalVaultBalance();
        // Вычисляем, какую сумму в токенах представляет заданное количество долей
        uint256 withdrawAmount = (shareAmount * totalBalance) / totalShares;

        // Сжигаем доли пользователя
        shares[msg.sender] -= shareAmount;
        totalShares -= shareAmount;

        uint256 vaultBalance = token.balanceOf(address(this));
        // Если на Vault недостаточно средств, выводим их из стратегий до полного покрытия суммы
        if (vaultBalance < withdrawAmount) {
            uint256 deficit = withdrawAmount - vaultBalance;
            /// Перебираем все стратегии, пока не покроем дефицит
            for (uint256 i = 0; i < strategies.length && deficit > 0; i++) {
                uint256 stratBalance = strategies[i].balance();
                if (stratBalance > 0) {
                    uint256 amountToWithdraw = stratBalance >= deficit ? deficit : stratBalance;
                    strategies[i].withdraw(amountToWithdraw);
                    vaultBalance = token.balanceOf(address(this));
                    if (vaultBalance >= withdrawAmount) {
                        deficit = 0;
                        break;
                    } else {
                        deficit = withdrawAmount - vaultBalance;
                    }
                }
            }
            require(token.balanceOf(address(this)) >= withdrawAmount, "Vault: Insufficient funds after strategy withdraws");
        }
        require(token.transfer(msg.sender, withdrawAmount), "Vault: Transfer failed");
        emit Withdraw(msg.sender, withdrawAmount, shareAmount);
    }


    /// функция для получения количества стратегий
    function getStrategiesCount() external view returns (uint256) {
        return strategies.length;
    }

    function activeStrategy() external view returns (IStrategy) {
        return strategies[activeStrategyIndex];
    }
}
