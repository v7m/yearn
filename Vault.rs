struct LiquidityPoolsProvider {
    pools: HashMap<String, Pool>,
    provider_id: String,
}

impl LiquidityPoolsProvider {
    get_pools()

    add_liquidity(token_0: String, amount_0: Nat, token_1: String, amount_1: Nat) -> AddLiquidityResponse
    
    remove_liquidity(token_0: String, token_1: String, lpAmount: Nat) -> RemoveLiquidityResponse

    user_balances(principal_id: String) -> UserBalancesResponse
}

// =======================================


// Pool хранит данные: name, token0, token1
struct Pool {
    provider_id: String,
    name: String,
    token0: String,
    token1: String,
    apy: f64,
}

impl Pool {
    fn get_apy() -> f64
}

struct UserAccount {
    // Сумма токенов, задепонированная пользователем
    initial_deposit: Nat,
    // Количество выпущенных долей, принадлежащих пользователю
    shares: Nat
}

struct Vault {
    pools: [],             // доступные для инвестирования пула (из разных провайдеров)
    total_balance: Nat,                         // общий баланс токенов
    total_shares: Nat,                          // общее количество выпущенных долей
    allocations: HashMap<String, Nat>,   // распределение ликвидности по пулам (имя пула -> количество токенов), сюда мы сохраняем пул, в котором в данный момент находится ликвидность
    user_accounts: HashMap<Principal, UserAccount>, // данные пользователей (см. UserAccount выше)
    current_pool: Option<String>,    // Текущий pool_id, в который инвестируются все средства
}

impl Vault {
    // Если общее количество долей больше 0, возвращаем общий баланс / общее количество долей
    fn share_price(&self) -> f64 {
        if self.total_shares > 0.0 {
            self.total_balance / self.total_shares
        } else {
            1.0
        }
    }

    fn deposit(amount: Nat) -> DepositResponse {
        // Рассчитываем долю юзера (shares)
        let share_price = if self.total_shares == 0.0 { 1.0 } else { self.total_balance / self.total_shares };
        let shares_to_mint = if self.total_balance == 0.0 || self.total_shares == 0.0 {
            amount
        } else {
            amount / share_price
        };

        self.total_balance += amount;
        self.total_shares += shares_to_mint;

        // Обновляем данные пользователя о новом депозите
        self.user_accounts
            .entry(user)
            .and_modify(|account| {
                account.initial_deposit += amount;
                account.shares += shares_to_mint;
            })
            .or_insert(UserAccount {
                initial_deposit: amount,
                shares: shares_to_mint,
            });


        if let Some(ref pool_id) = self.current_pool { // Если текущий пул установлен
            // Достаем текущий пул из allocations
            // token_0, token_1 = pool.token0, pool.token1
            // swap()
            // LiquidityPoolsProvider.add_liquidity(token_0: token_0, amount_0: Nat, token_1: token_1, amount_1: Nat)

        } else {
            // Если current_pool не установлен, вызываем rebalance(), который проложит ликвидность в нужный пул.
            rebalance();
        }
    }


    // Метод withdraw:
    // 1. Проверяем, достаточно ли у пользователя долей.
    // 2. Вычисляем сумму вывода по текущему share_price.
    // 3. Обновляем глобальные показатели и данные пользователя.
    // 4. Для текущего пула запрашиваем у провайдера баланс LP-токенов (user_balances) и вычисляем,
    // какую долю нужно вывести (lp_to_withdraw = total_lp * fraction).
    // Затем вызываем provider.remove_liquidity с параметрами token0, token1 и lp_to_withdraw.
    fn withdraw(shares: Nat) -> WithdrawResponse {
        // Проверяем, есть ли у пользователя достаточное количество долей
        let user_account = self.user_accounts.get_mut(&user).ok_or("Пользователь не найден")?;
        if shares > user_account.shares {
            return Err("У пользователя недостаточно долей для вывода".into());
        }

        // Рассчитываем сумму вывода, исходя из текущего share_price
        let share_price = self.share_price();
        let amount = shares * share_price;
        self.total_balance -= amount;
        self.total_shares -= shares;

        // Обновляем данные пользователя: уменьшаем доли и пропорционально уменьшаем первоначальный депозит
        let fraction = shares / user_account.shares;
        user_account.initial_deposit -= user_account.initial_deposit * fraction;
        user_account.shares -= shares;
        if user_account.shares <= 0.0 {
            self.user_accounts.remove(&user);
        }

        if let Some(ref pool_id) = self.current_pool {
            // Запрашиваем LP-токены для пользователя из провайдера -> LiquidityPoolsProvider.user_balances(principal_id: String)
            // Вычисляем, какую долю нужно вывести -> let lp_to_withdraw = total_lp * fraction;
            // remove_liquidity(token_0: String, token_1: String, lpAmount: lp_to_withdraw)
        }
    }

    rebalance() -> RebalanceResponse {
        // Находим пул с наибольшим APY
        let best_pool = self.pools.iter().max_by_key(|pool| pool.get_apy()).unwrap();

        // Если текущий пул не установлен, устанавливаем его
        self.current_pool = Some(best_pool.name.clone());


        // Перераспределяем ликвидность в пользу этого пула
        for (pool_id, amount) in self.allocations.iter() {
            // Если пул не лучший, переводим ликвидность в лучший пул
            if pool_id != best_pool.name {
                // token_0, token_1 = pool.token0, pool.token1
                // remove_liquidity(token_0: token_0, token_1: token_1, lpAmount: amount)
                // add_liquidity(token_0: token_0, amount_0: Nat, token_1: token_1, amount_1: Nat)
            }
        }
    }

    // возвращаем информацию о пользователе
    get_user_account() -> UserAccountInfo  {
        // Запрашиваем текущий баланс юзера LiquidityPoolsProvider.user_balances(principal_id: String)
        // получаем amount_0, amount_1, пересчитываем в доли
        // Рассчитываем текущую стоимость долей пользователя
        // обновляем данные пользователя в user_accounts

        UserAccountInfo {
            initial_deposit: user_accounts[user].initial_deposit,
            shares: user_accounts[user].shares,
            current_value: user_accounts[user].shares * self.share_price(),
        }    
    }

     // возвращаем информацию о волте
    get_info() -> VaultInfo {
        VaultInfo {
            total_balance: self.total_balance,
            total_shares: self.total_shares,
            share_price: self.share_price(),
            allocations: self.allocations.clone(),
            pools: self.current_pool.get_apy(),
        }
    }
}


struct DepositResponse {
    deposit_amount: Nat
    shares: Nat
}

struct WithdrawResponse {
    withdraw_amount: Nat
}

struct RebalanceResponse {
    allocations: HashMap<pool_name, Nat> // возвращаем пул, в который попала ликвидность
}

struct UserAccountInfo {
    initial_deposit: Nat
    shares: Nat,
    current_value: f64, // Текущая ликвидность пользователя, пересчитанная по актуальному курсу shares
}

struct VaultInfo {
    total_balance: f64,
    total_shares: f64,
    share_price: f64,
    allocations: HashMap<String, f64>, // pool_id -> allocated_amount
    apy: f64
}
