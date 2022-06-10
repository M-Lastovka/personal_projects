----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 06/29/2021 08:46:44 PM
-- Design Name: 
-- Module Name: dig_top_pckg 
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments: global package
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;


PACKAGE dig_top_pckg IS

    CONSTANT C_FFT_SIZE_LOG2  : natural := 12;                      
    CONSTANT C_FFT_SIZE       : natural := 2**C_FFT_SIZE_LOG2;      --number of samples
    CONSTANT C_SAMPLE_WDT     : natural := 24;                      --bit width of real/imag value
    CONSTANT C_DFT_WDT        : natural := 2*C_SAMPLE_WDT;          --width of data stored in memory (real + imag part)
    CONSTANT C_BUFFER_DELAY   : natural := 3;                       --how many clock cycles does it take to fill pipeline (sets delay between read and write)  
    CONSTANT C_SCALE_LOG2     : natural := C_SAMPLE_WDT-2;          --scaling constant for all the twiddle factors
    
    TYPE alg_command IS (
        SLEEP,
        RX,
        RX_SLEEP,
        RD_0_WR_1,
        RD_1_WR_0,
        SWEEP_FINISH,
        TX,
        TX_SLEEP
    );
    

END PACKAGE dig_top_pckg;

PACKAGE BODY dig_top_pckg IS 

END PACKAGE BODY dig_top_pckg;