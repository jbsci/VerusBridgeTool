# VerusBridgeTool

Script to interface with the Verus-Ethereum bridge to streamline making estimates as well as trades/swaps.

### Configuration

Set the parameters in the `bridgetool.conf` file. 

### Usage

Some basic usage:

#### Make an estimate

`./verusBridgeTool.sh -i VRSC -o vETH -a 100 -e`

#### Make a conversion

`./verusBridgeTool.sh -i VRSC -o vETH -a 100 -c`

#### Make a conversion if a target conversion value is reached

`./verusBridgeTool.sh -i VRSC -o vETH -a 100 -t 0.1

#### Make a conversion if a target is reached, but you'd be fine with a lower rate if it reaches at least that after 100 blocks

`./verusBridgeTool.sh -i VRSC -o vETH -a 100 -l 0.9 -u 0.1 -nblocks 100`

