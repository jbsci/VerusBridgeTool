#!/bin/bash

# Tool to interact with the verus-ethereum bridge.
# 
# Wraps a lot of the commands to a simple script
#
# Including the capability of auto-swapping between reserves and the bridge currency based on 
# a desired target value.
#
# No warranty or guarantees given, use at your own risk.

source ./bridgetool.conf

# # Functions

# HELP
show_help() {
	echo "Usage: $0 [options]"
	echo ""
	echo "Options:"
	echo " 	-e		        Gets estimate for currency exchange, cannot be used with -c and -t"
	echo "  -c 		        Performs conversion, cannot be used with -e and -t"
	echo "	-t	VALUE	        TARGET currency amount for exchange, cannot be used with -e and -c"
	echo "  -a	VALUE	        AMOUNT to be converted, \"all\" for all available"
	echo "	-i	VALUE	        INPUT currency"
	echo "	-o	VALUE	        OUTPUT currency"
        echo "  -l      VALUE           Lower limit for multi-limit values "
        echo "  -u      VALUE           Upper limit for multi-limit values"
        echo " --nblocks VALUE          Number of blocks to wait before switching from higher to lower limit"
        echo "  -b      VALUE           Limit block target. If the number of blocks set is exceeded AND the current exchange rate is higher than limit 1, but lower than limit 2 conversion is executed."
        echo "  -h                      Prints this help"
        echo " --sim    VALUE           Simulates arbitrage for n blocks"
        echo " --export VALUE           exports a specific currency to ETH specified by the amount in -a"
        echo " --gaslimit VALUE     threshold in gwei, defaults to 25"
	echo ""
}

# Checks if the input is in the valid list
check_currency_allowed() {
	local input_to_check=$1
	local allowed_list=$2
	local currency_found=false
	for allowed_currency in $allowed_list; do
		if [[ "$input_to_check" == "$allowed_currency" ]]; then
			currency_found=true
			break
		fi
	done
	if [ "$currency_found" == false ]; then
		return 1
	fi
	return 0
}

# Estimates currency conversion
estimate_conversion() {
    if [[ $input_currency == "bridge.vETH" ]] || [[ $output_currency == "bridge.vETH" ]]; then
        data=$($verus estimateconversion "{\"currency\" : \"$input_currency\", \"amount\" : $amount, \"convertto\" : \"$output_currency\"}")
    else
    data=$($verus estimateconversion "{\"currency\" : \"$input_currency\", \"amount\" : $amount, \"convertto\" : \"$output_currency\", \"via\" : \"bridge.vETH\"}")
    fi
    echo $data | jq '.estimatedcurrencyout'
}

# Performs conversion
send_currency() {
    if [[ $input_currency == "bridge.vETH" ]] || [[ $output_currency == "bridge.vETH" ]]; then
        $verus sendcurrency "*" "[{\"currency\" : \"$input_currency\", \"amount\" : $amount, \"convertto\": \"$output_currency\", \"address\" : \"$addresss\"}]" && echo "TRADE EXECUTED"
    else
        $verus sendcurrency "*" "[{\"currency\" : \"$input_currency\", \"amount\" : $amount, \"convertto\": \"$output_currency\", \"address\" : \"$address\", \"via\" : \"bridge.vETH\"}]" && echo "TRADE EXECUTED"
    fi
}

# # flags
while [[ $# -gt 0 ]]; do
    key="$1"

    case $key in
        -t)
            target_amount=$2
            shift # past argument
            shift # past value
            ;;
        -i)
            input_currency="$2"
            shift # past argument
            shift # past value
            ;;
        -o)
            output_currency="$2"
            shift # past argument
            shift # past value
            ;;
        -e)
            estimate=true
            shift # past argument
            ;;
        -c)
            convert=true
            shift # past argument
            ;;
        -a)
            if [[ "$2" == "all" ]]; then
                amount=$($verus getcurrencybalance "*" | jq ".$input_currency")
            else
                amount=$2
            fi
            shift # past argument
            shift # past value
            ;;
        -l)
            lower_limit=$2
            shift # past argument
            shift # past value
            ;;
        -u)
            upper_limit=$2
            shift # past argument
            shift # past value
            ;;
        --nblocks)
            number_blocks=$2
            shift # past argument
            shift # past value
            ;;
        --sim)
            sim=true
            shift # past argument
            shift # past value
            ;;
        --export)
            export=$2
            shift # past argument
            shift # past value
            ;;
        --gaslimit)
            gaslimit=$2
            shift # past argument
            shift # past value
        -h)
            show_help
            exit 0
            ;;
        *)    # unknown option
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Checks for any conflicting options
if [ -n "$upper_limit" ] && [ ! -n "$lower_limit" ]; then
        echo "You have to sepcify both a lower and upper limit"
        exit 1
fi
if [ -n "$lower_limit" ] && [ ! -n "$upper_limit" ]; then
        echo "You have to sepcify both a lower and upper limit"
        exit 1
fi
if [ -n "$lower_limit" ] && [ ! -n "$number_blocks" ]; then
        echo "Number of blocks to check must be given to use limits"
        exit 1
fi
if [ -n "$target_amount" ] && [ "$estimate" = true ]; then
	echo "Please either choose a target or to get an estimate, but not both"
	exit 1
fi
if [ -n "$lower_limit" ] && [ "$estimate" = true ]; then
	echo "Please either choose a target or to get an estimate, but not both"
	exit 1
fi
if [ -n "$target_amount" ] && [ "$convert" = true ]; then
	echo "Please either choose a target or to do a conversion, but not both"
	exit 1
fi
if [ -n "$lower_limit" ] && [ "$convert" = true ]; then
	echo "Please either choose a target or to do a conversion, but not both"
	exit 1
fi
if [ -n "$target_amount" ] && [ -n "$lower_limit" ]; then
	echo "Cant set target and lower/upper limits"
	exit 1
fi
if [ -n "$target_amount" ] && [ -n "$upper_limit" ]; then
	echo "Cant set target and lower/upper limits"
	exit 1
fi
if [ "$estimate" = true ] && [ "$convert" = true ]; then
	echo "Please either choose do make an estimate or to do a conversion, but not both"
	exit 1
fi
# Checks that the input currency is valid
if ! check_currency_allowed "$input_currency" "$allowed_currencies"; then
	echo "Error: Invalid input currency"
        exit 1
fi
# Checks that the output currency is valid
if ! check_currency_allowed "$output_currency" "$allowed_currencies"; then
	echo "Error: Invalid output currency"
        exit 1
fi
## Main program
if [ "$estimate" = true ]; then
    estimate_conversion
    exit 0
fi

if [ "$convert" = true ]; then
    send_currency
    exit 0
fi

if [ -n "$target_amount" ]; then
    until [ $(echo "$(estimate_conversion) >= $target_amount" | bc -l) -eq 1 ]; do
		echo "Curretly less than threshold ($(estimate_conversion) vs $target_amount). Sleeping..."
		sleep $target_rate
    done
    send_currency
    exit 0
fi

if [ -n "$lower_limit" ]; then
    current_height=$($verus getinfo | jq '.blocks')
    check_height=$(echo "$current_height + $number_blocks" | bc)
    echo "Starting to check at height $current_height", will switch to lower limit at $check_height
    until [ $current_height -gt $check_height ];  do
        if [ $(echo "$(estimate_conversion) >= $upper_limit" | bc -l) -eq 1 ]; then
            send_currency
            exit 0
        else
            echo "Currently less than upper limit of $upper_limit ($(estimate_conversion)) at height $current_height ($(echo "$check_height - $current_height" | bc) blocks to go), sleeping..."
            sleep $target_rate
            current_height=$($verus getinfo | jq '.blocks')
        fi
    done
    echo "Block limit exceeded, checking against lower limit of $lower_limit now."
    until [ $(echo "$(estimate_conversion) >= $lower_limit" | bc -l) -eq 1 ]; do
        echo "Currently less than lower limit $lower_limit ($(estimate_conversion)). Sleeping..."
		sleep $target_rate
    done
    send_currency
    exit 0
fi
if [ "$sim" = true ]; then
    init_swap=$(estimate_conversion)
    old_input="$input_currency"
    old_output="$output_currency"
    input_currency="$old_output"
    output_currency="$old_input"
    start_amount="$amount"
    amount="$init_swap"
    while true; do
        current_est=$(estimate_conversion)
        delta=$(echo "$current_est - $start_amount" | bc)
        echo "Initial $start_amount of $old_input converted to $init_swap $old_output."
        echo "If you converted that back, you'd have $current_est (delta of $delta)"
        sleep $target_rate
    done
    exit 0
fi
if [ -n "$export" ]; then
    #TODO Add export support
    echo "Nothing here yet"
fi





