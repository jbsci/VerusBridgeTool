# VerusBridgeTool

Script to interface with the Verus-Ethereum bridge to streamline making estimates and arbitrage. 

Includes the ability to make "limit" trades.

### Configuration

Set the parameters in the `bridgetool.conf` file, example:

```
verus="$HOME/bin/verus"
address="RJeP52dSE3FZtE6NHcaZGYh6Qs1Vksmeq9"
target_rate=60
allowed_currencies="VRSC vETH MKR.vETH bridge.vETH DAI.vETH"
```

### Usage

#### Make an estimate

`./verusBridgeTool.sh -i VRSC -o vETH -a 100 -e`

#### Make a conversion

`./verusBridgeTool.sh -i VRSC -o vETH -a 100 -c`

#### Make a conversion when a target conversion value is reached (check interval is set with the target_rate parameter in the config)

`./verusBridgeTool.sh -i VRSC -o vETH -a 100 -t 0.1`

#### Make a conversion if a target is reached, but you'd be fine with a lower rate if it reaches at least that after 100 blocks

`./verusBridgeTool.sh -i VRSC -o vETH -a 100 -l 0.9 -u 0.1 -nblocks 100`

