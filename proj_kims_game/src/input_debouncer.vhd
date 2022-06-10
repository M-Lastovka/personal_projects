----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 06/29/2021 09:10:11 PM
-- Design Name: 
-- Module Name: in_btn_debouncer - rtl
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments: debounces input button signals
-- 
----------------------------------------------------------------------------------


LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
LIBRARY work;
USE work.dig_top_pckg.ALL;


ENTITY input_debouncer IS
    PORT ( 
           clk_in         : IN  std_logic;
           reset_n_in     : IN  std_logic; 
            
           usr_btn_c_in :   IN  std_logic_vector (3 DOWNTO 0);
           usr_btn      :   OUT std_logic_vector (3 DOWNTO 0)
           );
END input_debouncer;

ARCHITECTURE rtl OF input_debouncer IS

    SIGNAL  usr_btn_sync_i :   std_logic_vector(3 DOWNTO 0);           --internal signal of double FF synchronizer
    SIGNAL  usr_btn_sync   :   std_logic_vector(3 DOWNTO 0);           --user input synchronized by double FF
    
    COMPONENT single_bit_debouncer
        PORT ( 
           clk_in         : IN  std_logic;
           reset_n_in     : IN  std_logic; 
            
           d_in  :   IN  std_logic;
           d_out :   OUT std_logic
           );
    END COMPONENT single_bit_debouncer;

BEGIN

    double_sync : PROCESS(clk_in, reset_n_in) IS
    BEGIN
        IF(reset_n_in = '0') THEN
            usr_btn_sync_i  <= "0000";
            usr_btn_sync    <= "0000";
        ELSIF(rising_edge(clk_in)) THEN
            usr_btn_sync_i  <= usr_btn_c_in;
            usr_btn_sync    <= usr_btn_sync_i;
        END IF;
    END PROCESS double_sync;
    
    gen_debounce : FOR i IN 0 TO 3 GENERATE
        debouncers : single_bit_debouncer
            PORT MAP (
                clk_in          => clk_in,
                reset_n_in      => reset_n_in,
                d_in            => usr_btn_c_in(i),
                d_out           => usr_btn(i)
            );
    END GENERATE gen_debounce;
    

END rtl;
