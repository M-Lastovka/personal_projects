----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 06/29/2021 11:01:51 PM
-- Design Name: 
-- Module Name: single_bit_debouncer - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: PRERESET value has to be defined (C_DEBOUNCE_DELAY)
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments: simple 1 bit debouncer
-- 
----------------------------------------------------------------------------------


LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
LIBRARY work;
USE work.dig_top_pckg.ALL;


ENTITY single_bit_debouncer IS
    PORT ( 
           clk_in         : IN  std_logic;
           reset_n_in     : IN  std_logic; 
            
           d_in  :   IN  std_logic;
           d_out :   OUT std_logic
           );
END single_bit_debouncer;

ARCHITECTURE rtl OF single_bit_debouncer IS

    SIGNAL  buffer_cnt  :   natural RANGE 0 TO 65535;
BEGIN

    buff_cnt : PROCESS(clk_in,reset_n_in) IS
    BEGIN
    
      IF(reset_n_in = '0') THEN
        d_out        <= '0';
        buffer_cnt   <= C_DEBOUNCE_DELAY;
      ELSIF(rising_edge(clk_in)) THEN           
        IF(d_in = '0') THEN                     --input has changed, reset counter
            d_out        <= '0';
            buffer_cnt   <= C_DEBOUNCE_DELAY;
        ELSIF(d_in = '1') THEN
            IF(buffer_cnt > 0) THEN             --continue with decrementing counter while input is held high
                d_out        <= '0';
                buffer_cnt   <= buffer_cnt - 1;
            ELSE
                d_out        <= '1';            --input is stable long enough, assert high
                buffer_cnt   <= buffer_cnt;
            END IF;
        END IF;
      END IF;
    
    END PROCESS buff_cnt;


    ASSERT buffer_cnt <= C_DEBOUNCE_DELAY REPORT "Faulty debounce counter value!" severity error;

END rtl;

