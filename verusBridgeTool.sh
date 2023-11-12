#!/bin/bash

# Tool to interact with the verus-ethereum bridge.
# 
# Wraps a lot of the commands to a simple script
#
# Including the capability of auto-swapping between reserves and the bridge currency based on 
# a desired target value.
#
# No warranty or guarantees given, use at your own risk.


# # Constants

# Path to verus executable
verus=
# Desired address to use on the verus side, not required if only wanting to do estimates
address=
# List of allowed currencies
allowed_currencies="VRSC vETH MKR.vETH bridge.vETH"

# # Functions

# HELP
show_help() {
	echo "Usage: $0 [options]"
	echo ""
	echo "Options:"
	echo " 	-e		Gets estimate for currency exchange, cannot be used with -c and -t"
	echo "  -c 		Performs conversion, cannot be used with -e and -t"
	echo "	-t	VALUE	TARGET currency amount for exchange, cannot be used with -e and -c"
	echo "  -a	VALUE	AMOUNT to be converted"
	echo "	-i	VALUE	INPUT currency"
	echo "	-o	VALUE	OUTPUT currency"
        echo "  -h              Prints this help"
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

estimate_conversion() {
    if [[ $input_currency == "bridge.vETH" ]] || [[ $output_currency == "bridge.vETH" ]]; then
        data=$($verus estimateconversion "{\"currency\" : \"$input_currency\", \"amount\" : $amount, \"convertto\" : \"$output_currency\"}")
    else
    data=$($verus estimateconversion "{\"currency\" : \"$input_currency\", \"amount\" : $amount, \"convertto\" : \"$output_currency\", \"via\" : \"bridge.vETH\"}")
    fi
    echo $data | jq '.estimatedcurrencyout'
}

send_currency() {
    if [[ $input_currency == "bridge.vETH" ]] || [[ $output_currency == "bridge.vETH" ]]; then
        $verus sendcurrency "*" "[{\"currency\" : \"$input_currency\", \"amount\" : $amount, \"convertto\": \"$output_currency\", \"address\" : \"$addresss\"}]" && echo "TRADE EXECUTED"
    else
        $verus sendcurrency "*" "[{\"currency\" : \"$input_currency\", \"amount\" : $amount, \"convertto\": \"$output_currency\", \"address\" : \"$address\", \"via\" : \"bridge.vETH\"}]" && echo "TRADE EXECUTED"
    fi
}

# # flags

while getopts ":t:i:o:a:ech" option; do
	case $option in
		t)
			target_amount="$OPTARG"
			;;

		i)
			input_currency="$OPTARG"
			;;
	  	o)
			output_currency="$OPTARG"
			;;
		e)
			estimate=true
			;;
		c)
			convert=true
			;;
		a)
			amount="$OPTARG"
			;;
		h)
			show_help
			exit 0
			;;

		\?)
			echo "Invalid option: -$OPTART" >&2
			exit 1
			;;
		:)
			echo "Option -$OPTARG requires an argument." >&2
			;;
	esac
done

# Checks if trying to do a trade at a target value, do a single conversion, or make an estimate. Cannot do all at the same time.
if [ -n "$target_amount" ] && [ "$estimate" = true ]; then
	echo "Please either choose a target or to get an estimate, but not both"
	exit 1
fi

if [ -n "$target_amount" ] && [ "$convert" = true ]; then
	echo "Please either choose a target or to do a conversion, but not both"
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

if [ "$convert" = true ]; then
    send_currency

if [ -n "$target_amount" ]; then
    until [ $(echo "$(estimate_conversion) >= $target_amount" | bc -l) -eq 1 ]; do
		echo "Curretly less than threshold ($(estimate_conversion) vs $target_amount). Sleeping..."
		sleep 60
    done
    send_currency
fi
