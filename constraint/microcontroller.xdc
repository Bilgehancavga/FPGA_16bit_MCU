####################################################
# Nexys A7-100T
# MCU_top Constraints
####################################################


############################
# CLOCK 100 MHz
############################

set_property -dict { PACKAGE_PIN E3 IOSTANDARD LVCMOS33 } [get_ports {clk}]
create_clock -period 10.000 -name sys_clk_pin -waveform {0 5} [get_ports {clk}]


############################
# RESET BUTTON
############################

set_property -dict { PACKAGE_PIN C12 IOSTANDARD LVCMOS33 } [get_ports {button_reset}]


############################
# UART RX
############################

# PC/FTDI TX -> FPGA RX
set_property -dict { PACKAGE_PIN C4 IOSTANDARD LVCMOS33 } [get_ports {uart_rx}]


############################
# UART FRAMING ERROR
# RGB LED16 RED
############################

set_property -dict { PACKAGE_PIN N15 IOSTANDARD LVCMOS33 } [get_ports {uart_framing_err}]


############################
# LED OUTPUTS
############################

set_property -dict { PACKAGE_PIN H17 IOSTANDARD LVCMOS33 } [get_ports {led_out[0]}]
set_property -dict { PACKAGE_PIN K15 IOSTANDARD LVCMOS33 } [get_ports {led_out[1]}]
set_property -dict { PACKAGE_PIN J13 IOSTANDARD LVCMOS33 } [get_ports {led_out[2]}]
set_property -dict { PACKAGE_PIN N14 IOSTANDARD LVCMOS33 } [get_ports {led_out[3]}]

set_property -dict { PACKAGE_PIN R18 IOSTANDARD LVCMOS33 } [get_ports {led_out[4]}]
set_property -dict { PACKAGE_PIN V17 IOSTANDARD LVCMOS33 } [get_ports {led_out[5]}]
set_property -dict { PACKAGE_PIN U17 IOSTANDARD LVCMOS33 } [get_ports {led_out[6]}]
set_property -dict { PACKAGE_PIN U16 IOSTANDARD LVCMOS33 } [get_ports {led_out[7]}]

set_property -dict { PACKAGE_PIN V16 IOSTANDARD LVCMOS33 } [get_ports {led_out[8]}]
set_property -dict { PACKAGE_PIN T15 IOSTANDARD LVCMOS33 } [get_ports {led_out[9]}]
set_property -dict { PACKAGE_PIN U14 IOSTANDARD LVCMOS33 } [get_ports {led_out[10]}]
set_property -dict { PACKAGE_PIN T16 IOSTANDARD LVCMOS33 } [get_ports {led_out[11]}]

set_property -dict { PACKAGE_PIN V15 IOSTANDARD LVCMOS33 } [get_ports {led_out[12]}]
set_property -dict { PACKAGE_PIN V14 IOSTANDARD LVCMOS33 } [get_ports {led_out[13]}]
set_property -dict { PACKAGE_PIN V12 IOSTANDARD LVCMOS33 } [get_ports {led_out[14]}]
set_property -dict { PACKAGE_PIN V11 IOSTANDARD LVCMOS33 } [get_ports {led_out[15]}]


############################
# SEVEN SEGMENT
# seven_segment[0] = A
# seven_segment[1] = B
# seven_segment[2] = C
# seven_segment[3] = D
# seven_segment[4] = E
# seven_segment[5] = F
# seven_segment[6] = G
############################

set_property -dict { PACKAGE_PIN T10 IOSTANDARD LVCMOS33 } [get_ports {seven_segment[0]}]
set_property -dict { PACKAGE_PIN R10 IOSTANDARD LVCMOS33 } [get_ports {seven_segment[1]}]
set_property -dict { PACKAGE_PIN K16 IOSTANDARD LVCMOS33 } [get_ports {seven_segment[2]}]
set_property -dict { PACKAGE_PIN K13 IOSTANDARD LVCMOS33 } [get_ports {seven_segment[3]}]
set_property -dict { PACKAGE_PIN P15 IOSTANDARD LVCMOS33 } [get_ports {seven_segment[4]}]
set_property -dict { PACKAGE_PIN T11 IOSTANDARD LVCMOS33 } [get_ports {seven_segment[5]}]
set_property -dict { PACKAGE_PIN L18 IOSTANDARD LVCMOS33 } [get_ports {seven_segment[6]}]

# Decimal point
set_property -dict { PACKAGE_PIN H15 IOSTANDARD LVCMOS33 } [get_ports {dp}]


############################
# ANODE DIGIT SELECT
############################

set_property -dict { PACKAGE_PIN J17 IOSTANDARD LVCMOS33 } [get_ports {anode[0]}]
set_property -dict { PACKAGE_PIN J18 IOSTANDARD LVCMOS33 } [get_ports {anode[1]}]
set_property -dict { PACKAGE_PIN T9  IOSTANDARD LVCMOS33 } [get_ports {anode[2]}]
set_property -dict { PACKAGE_PIN J14 IOSTANDARD LVCMOS33 } [get_ports {anode[3]}]

set_property -dict { PACKAGE_PIN P14 IOSTANDARD LVCMOS33 } [get_ports {anode[4]}]
set_property -dict { PACKAGE_PIN T14 IOSTANDARD LVCMOS33 } [get_ports {anode[5]}]
set_property -dict { PACKAGE_PIN K2  IOSTANDARD LVCMOS33 } [get_ports {anode[6]}]
set_property -dict { PACKAGE_PIN U13 IOSTANDARD LVCMOS33 } [get_ports {anode[7]}]


############################
# SWITCH INPUTS
############################

set_property -dict { PACKAGE_PIN J15 IOSTANDARD LVCMOS33 } [get_ports {sws[0]}]
set_property -dict { PACKAGE_PIN L16 IOSTANDARD LVCMOS33 } [get_ports {sws[1]}]
set_property -dict { PACKAGE_PIN M13 IOSTANDARD LVCMOS33 } [get_ports {sws[2]}]
set_property -dict { PACKAGE_PIN R15 IOSTANDARD LVCMOS33 } [get_ports {sws[3]}]

set_property -dict { PACKAGE_PIN R17 IOSTANDARD LVCMOS33 } [get_ports {sws[4]}]
set_property -dict { PACKAGE_PIN T18 IOSTANDARD LVCMOS33 } [get_ports {sws[5]}]
set_property -dict { PACKAGE_PIN U18 IOSTANDARD LVCMOS33 } [get_ports {sws[6]}]
set_property -dict { PACKAGE_PIN R13 IOSTANDARD LVCMOS33 } [get_ports {sws[7]}]

# SW8 and SW9 are in the 1.8 V bank
set_property -dict { PACKAGE_PIN T8 IOSTANDARD LVCMOS18 } [get_ports {sws[8]}]
set_property -dict { PACKAGE_PIN U8 IOSTANDARD LVCMOS18 } [get_ports {sws[9]}]

set_property -dict { PACKAGE_PIN R16 IOSTANDARD LVCMOS33 } [get_ports {sws[10]}]
set_property -dict { PACKAGE_PIN T13 IOSTANDARD LVCMOS33 } [get_ports {sws[11]}]
set_property -dict { PACKAGE_PIN H6  IOSTANDARD LVCMOS33 } [get_ports {sws[12]}]
set_property -dict { PACKAGE_PIN U12 IOSTANDARD LVCMOS33 } [get_ports {sws[13]}]
set_property -dict { PACKAGE_PIN U11 IOSTANDARD LVCMOS33 } [get_ports {sws[14]}]
set_property -dict { PACKAGE_PIN V10 IOSTANDARD LVCMOS33 } [get_ports {sws[15]}]


############################
# BUTTON INPUTS
#
# btn_in[0] = UP
# btn_in[1] = LEFT
# btn_in[2] = CENTER
# btn_in[3] = RIGHT
# btn_in[4] = DOWN
############################

set_property -dict { PACKAGE_PIN M18 IOSTANDARD LVCMOS33 } [get_ports {btn_in[0]}]
set_property -dict { PACKAGE_PIN P17 IOSTANDARD LVCMOS33 } [get_ports {btn_in[1]}]
set_property -dict { PACKAGE_PIN N17 IOSTANDARD LVCMOS33 } [get_ports {btn_in[2]}]
set_property -dict { PACKAGE_PIN M17 IOSTANDARD LVCMOS33 } [get_ports {btn_in[3]}]
set_property -dict { PACKAGE_PIN P18 IOSTANDARD LVCMOS33 } [get_ports {btn_in[4]}]


############################
# GENERAL PURPOSE PINS BUS
#
# pins[0:7]  -> PMOD JA
# pins[8:15] -> PMOD JC
############################

# PMOD JA
set_property -dict { PACKAGE_PIN C17 IOSTANDARD LVCMOS33 } [get_ports {pins[0]}]
set_property -dict { PACKAGE_PIN D18 IOSTANDARD LVCMOS33 } [get_ports {pins[1]}]
set_property -dict { PACKAGE_PIN E18 IOSTANDARD LVCMOS33 } [get_ports {pins[2]}]
set_property -dict { PACKAGE_PIN G17 IOSTANDARD LVCMOS33 } [get_ports {pins[3]}]

set_property -dict { PACKAGE_PIN D17 IOSTANDARD LVCMOS33 } [get_ports {pins[4]}]
set_property -dict { PACKAGE_PIN E17 IOSTANDARD LVCMOS33 } [get_ports {pins[5]}]
set_property -dict { PACKAGE_PIN F18 IOSTANDARD LVCMOS33 } [get_ports {pins[6]}]
set_property -dict { PACKAGE_PIN G18 IOSTANDARD LVCMOS33 } [get_ports {pins[7]}]


# PMOD JC
set_property -dict { PACKAGE_PIN K1 IOSTANDARD LVCMOS33 } [get_ports {pins[8]}]
set_property -dict { PACKAGE_PIN F6 IOSTANDARD LVCMOS33 } [get_ports {pins[9]}]
set_property -dict { PACKAGE_PIN J2 IOSTANDARD LVCMOS33 } [get_ports {pins[10]}]
set_property -dict { PACKAGE_PIN G6 IOSTANDARD LVCMOS33 } [get_ports {pins[11]}]

set_property -dict { PACKAGE_PIN E7 IOSTANDARD LVCMOS33 } [get_ports {pins[12]}]
set_property -dict { PACKAGE_PIN J3 IOSTANDARD LVCMOS33 } [get_ports {pins[13]}]
set_property -dict { PACKAGE_PIN J4 IOSTANDARD LVCMOS33 } [get_ports {pins[14]}]
set_property -dict { PACKAGE_PIN E6 IOSTANDARD LVCMOS33 } [get_ports {pins[15]}]


############################
# PWM OUTPUT
# PMOD JD1
#
# Separate from pins[0:15],
# so there is NO pin conflict.
############################

set_property -dict { PACKAGE_PIN H4 IOSTANDARD LVCMOS33 } [get_ports {pwm_pin}]


####################################################
# END
####################################################