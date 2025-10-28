#!/bin/bash

POWER_BUTTON_GPIO=234

# 3 kHz, 50% volume
DUTY_CYCLE=166666
PERIOD=333333


# Bootlet should be compatible with both WB8.4 & WB8.5+ devices
# Since WB8.5, buzzer is available via embedded-controller & wbec-pwm driver
# => enable both (wbec & t507) buzzer PWMs in bootlet dts and guess pwmchip & pwmbuzzer via WBEC hwrev
get_pwmchip_pwmbuzzer() {
    local pwm_buzzer
    local pwm_chip
    local compatible

    local wbec_hwrev=$(cat /sys/bus/spi/drivers/wbec/spi0.0/hwrev 2>/dev/null || true)
    case $wbec_hwrev in
        "85")
            pwm_buzzer="0"
            compatible="wirenboard,wbec-pwm"
            ;;
        *)
            pwm_buzzer="1"
            compatible="allwinner,sun50i-t507-pwm"
            ;;
    esac

    pwm_chip=$(grep -H $compatible /sys/class/pwm/pwmchip*/device/of_node/compatible | grep -Eo "pwmchip[[:digit:]]+")
    echo "$pwm_chip $pwm_buzzer"
}

buzzer_init() {
    local r1=1
    local r2=1

    local chip_buzzer="$(get_pwmchip_pwmbuzzer)"
    local pwmchip="$(echo $chip_buzzer | awk '{print $1}')"
    local pwmbuzzer="$(echo $chip_buzzer | awk '{print $2}')"

    while [ $r1 -ne 0 ] || [ $r2 -ne 0 ]; do
        echo "$pwmbuzzer" > /sys/class/pwm/$pwmchip/export 2> /dev/null || true
        echo "$PERIOD" > /sys/class/pwm/$pwmchip/pwm${pwmbuzzer}/period 2> /dev/null
        r1=$?
        echo "$DUTY_CYCLE" > /sys/class/pwm/$pwmchip/pwm${pwmbuzzer}/duty_cycle 2> /dev/null
        r2=$?
    done
}

buzzer_on() {
    local chip_buzzer="$(get_pwmchip_pwmbuzzer)"
    local pwmchip="$(echo $chip_buzzer | awk '{print $1}')"
    local pwmbuzzer="$(echo $chip_buzzer | awk '{print $2}')"

    echo "1" > /sys/class/pwm/$pwmchip/pwm${pwmbuzzer}/enable 2> /dev/null
}

buzzer_off() {
    local chip_buzzer="$(get_pwmchip_pwmbuzzer)"
    local pwmchip="$(echo $chip_buzzer | awk '{print $1}')"
    local pwmbuzzer="$(echo $chip_buzzer | awk '{print $2}')"

    echo "0" > /sys/class/pwm/$pwmchip/pwm${pwmbuzzer}/enable 2> /dev/null
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
