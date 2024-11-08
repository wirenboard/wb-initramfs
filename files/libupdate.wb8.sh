#!/bin/bash

POWER_BUTTON_GPIO=234

# 3 kHz, 50% volume
DUTY_CYCLE=166666
PERIOD=333333


# Bootlet should be compatible with both WB8.4 & WB8.5+ devices
# Since WB8.5, buzzer is available via embedded-controller & wbec-pwm driver
# => enable both (wbec & t507) buzzer PWMs in bootlet dts and guess pwmchip & pwmbuzzer onthefly

get_possible_pwmchips() {
    local pwmchips=""
    for compat in "allwinner,sun50i-t507-pwm" "wirenboard,wbec-pwm"; do
        pwmchips="$pwmchips $(grep -H $compat /sys/class/pwm/pwmchip*/device/of_node/compatible | grep -Eo "pwmchip[[:digit:]]+")"
    done
    echo $pwmchips
}

# both wbec & non-wbec pwm drivers have hardcoded pwm outputs (unavailable to change via dts)
get_pwm_buzzer() {
    local pwmchip=$1
    local compat=$(tr -d '\0' < "/sys/class/pwm/$pwmchip/device/of_node/compatible")
    case $compat in
        "wirenboard,wbec-pwm")
            echo "0"
            ;;
        *)
            echo "1"
            ;;
    esac
}

buzzer_init() {
    local r1=1
    local r2=1
    while [ $r1 -ne 0 ] || [ $r2 -ne 0 ]; do
        for pwmchip in $(get_possible_pwmchips); do

            local pwm_buzzer=$(get_pwm_buzzer $pwmchip)
            echo "$pwm_buzzer" > /sys/class/pwm/$pwmchip/export 2> /dev/null || true

            echo "$PERIOD" > /sys/class/pwm/$pwmchip/pwm${pwm_buzzer}/period 2> /dev/null
            r1=$?

            echo "$DUTY_CYCLE" > /sys/class/pwm/$pwmchip/pwm${pwm_buzzer}/duty_cycle 2> /dev/null
            r2=$?
        done
    done
}

buzzer_on() {
    for pwmchip in $(get_possible_pwmchips); do
        local pwm_buzzer=$(get_pwm_buzzer $pwmchip)
        echo "1" > /sys/class/pwm/$pwmchip/pwm${pwm_buzzer}/enable 2> /dev/null
    done
}

buzzer_off() {
    for pwmchip in $(get_possible_pwmchips); do
        local pwm_buzzer=$(get_pwm_buzzer $pwmchip)
        echo "0" > /sys/class/pwm/$pwmchip/pwm${pwm_buzzer}/enable 2> /dev/null
    done
}

button_init() {
    echo $POWER_BUTTON_GPIO > /sys/class/gpio/export 2>/dev/null || true
    echo in > /sys/class/gpio/gpio${POWER_BUTTON_GPIO}/direction 2>/dev/null || true
}

button_read() {
    cat /sys/class/gpio/gpio${POWER_BUTTON_GPIO}/value
}

button_up() {
    [ `button_read` == 1 ]
}

button_down() {
    [ `button_read` == 0 ]
}
