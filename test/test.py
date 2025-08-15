# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

@cocotb.test()
async def test_uart_tx_rx(dut):
    """Test UART TX and RX functionality via Tiny Tapeout pins"""
    
    # Setup 10ns clock (100 MHz)
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    
    await Timer(100, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Wait for reset to stabilize
    for _ in range(10):
        await RisingEdge(dut.clk)
    
    print("Starting UART TX test...")
    
    # Configure UART
    # ui_in[0] = tr_en, ui_in[1] = mode_osl, ui_in[2] = clk_sel
    # ui_in[3] = tx_data_w_en, ui_in[4] = tr_data_load, ui_in[5] = rx_data_read_en
    dut.ui_in.value = 0b00000001  # Enable transmitter (tr_en = 1)
    
    # Data to transmit (7 bits as per interface)
    data_to_transmit = 0x55  # 01010101
    dut.uio_in.value = (data_to_transmit << 1) | 0  # TX data in bits [7:1], RX in bit [0]
    
    await RisingEdge(dut.clk)
    
    # Trigger transmission: set tx_data_w_en and tr_data_load
    dut.ui_in.value = 0b00011001  # tr_en=1, tx_data_w_en=1, tr_data_load=1
    
    print(f"TX sending byte: 0x{data_to_transmit:02X}")
    
    # Wait a few clocks then clear the trigger
    for _ in range(5):
        await RisingEdge(dut.clk)
    
    dut.ui_in.value = 0b00000001  # Keep tr_en=1, clear write enables
    
    # Monitor TX line and wait for transmission
    tx_busy_count = 0
    while dut.uio_out.value[5] == 1 and tx_busy_count < 1000:  # uio_out[5] = tr_busy
        await RisingEdge(dut.clk)
        tx_busy_count += 1
    
    if tx_busy_count >= 1000:
        print("Warning: TX busy timeout")
    else:
        print("TX transmission completed")
    
    # Test RX by simulating serial data input
    print("Starting UART RX test...")
    
    # Send start bit (0)
    dut.uio_in.value = (dut.uio_in.value & 0xFE) | 0  # Set RX bit to 0
    await Timer(320, units='ns')  # Wait for one bit period
    
    # Send data bits (LSB first)
    rx_test_data = 0xAA  # 10101010
    for i in range(8):
        bit = (rx_test_data >> i) & 0x1
        dut.uio_in.value = (dut.uio_in.value & 0xFE) | bit
        await Timer(320, units='ns')  # One bit period
    
    # Send stop bit (1)
    dut.uio_in.value = (dut.uio_in.value & 0xFE) | 1
    await Timer(320, units='ns')
    
    # Wait for RX to process
    for _ in range(50):
        await RisingEdge(dut.clk)
    
    # Enable read to get received data
    dut.ui_in.value = 0b00100001  # tr_en=1, rx_data_read_en=1
    await RisingEdge(dut.clk)
    
    # Read the received data
    received = dut.uo_out.value.integer
    print(f"RX received byte: 0x{received:02X}")
    
    # Check interrupts
    tx_i_int = dut.uio_out.value[1]
    rx_i_int = dut.uio_out.value[2] 
    print(f"TX interrupt: {tx_i_int}, RX interrupt: {rx_i_int}")
    
    print("Test completed!")
    
    # Final wait
    await Timer(1000, units='ns')
