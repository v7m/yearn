# ICPSwap

https://github.com/ICPSwap-Labs/docs

### ckBTC pools
ckBTC/ICP (poolId: xmiu5-jqaaa-aaaag-qbz7q-cai) \
ckBTC/ckETH

### ckUSDC pools
ckUSDT / ckUSDC

https://dashboard.internetcomputer.org/canister/mjfzu-6qaaa-aaaag-qclfa-cai - getPool(poolId)

#### Response

```
    {
        id = 20_152 : nat;
        token0TotalVolume = 2958217.650604291 : float64;
        volumeUSD1d = 100696.7436592294 : float64;
        volumeUSD7d = 1349345.8578678814 : float64;
        token0Id = "mxzaz-hqaaa-aaaar-qaada-cai";
        token1Id = "ryjl3-tyaaa-aaaaa-aaaba-cai";
        token1Volume24H = 16484.115927299994 : float64;
        totalVolumeUSD = 53679430.84415853 : float64;
        sqrtPrice = 14206.69577874818 : float64;
        pool = "xmiu5-jqaaa-aaaag-qbz7q-cai";
        tick = 95_588 : int;
        liquidity = 0 : nat;
        token1Price = 6.350424698667819 : float64;
        feeTier = 3_000 : nat;
        token1TotalVolume = 2953704.3517685616 : float64;
        volumeUSD = 100779.8556294617 : float64;
        feesUSD = 241.6721847821505 : float64;
        token0Volume24H = 1.1413471800000023 : float64;
        token1Standard = "ICP";
        txCount = 539 : nat;
        token1Decimals = 8.0 : float64;
        token0Standard = "ICRC2";
        token0Symbol = "ckBTC";
        token0Decimals = 8.0 : float64;
        token0Price = 90218.5517598223 : float64;
        token1Symbol = "ICP";
    }
```

#### APR/APY calculating
```
    days_in_year = 365

    # Суточные комиссии
    feesUSD = volumeUSD1d * (feeTier.to_f / 1_000_000)  

    # Расчет APR
    apr = (feesUSD * days_in_year / liquidity) * 100  

    # Расчет APY с учетом сложных процентов
    apy = ((1 + apr / 100 / days_in_year) ** days_in_year - 1) * 100
```






# KongSwap

https://github.com/KongSwap/kong

### ckBTC pools
ckBTC/ckUSDT ?

### ckUSDC pools
ckUSDC/ckUSDT