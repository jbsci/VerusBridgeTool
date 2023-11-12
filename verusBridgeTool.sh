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
	echo "  -a	VALUE	        AMOUNT to be converted"
	echo "	-i	VALUE	        INPUT currency"
	echo "	-o	VALUE	        OUTPUT currency"
        echo "  -l      VALUE           Lower limit for multi-limit values "
        echo "  -u      VALUE           Upper limit for multi-limit values"
        echo "  -b      VALUE           Limit block target. If the number of blocks set is exceeded AND the current exchange rate is higher than limit 1, but lower than limit 2 conversion is executed."
        echo "  -h                      Prints this help"
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
            amount=$2
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
fi
# Checks that the output currency is valid
if ! check_currency_allowed "$output_currency" "$allowed_currencies"; then
	echo "Error: Invalid input currency"
fi
## Main program
if [ "$estimate" = true ]; then
    estimate_conversion
fi

if [ "$convert" = true ]; then
    send_currency
fi

if [ -n "$target_amount" ]; then
    until [ $(echo "$(estimate_conversion) >= $target_amount" | bc -l) -eq 1 ]; do
		echo "Curretly less than threshold ($(estimate_conversion) vs $target_amount). Sleeping..."
		sleep $target_rate
    done
    send_currency
fi
