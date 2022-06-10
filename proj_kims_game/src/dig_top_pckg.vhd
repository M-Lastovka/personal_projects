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

    CONSTANT C_DEBOUNCE_DELAY : natural := 60_000;      --used for debouncing user input buttons
    CONSTANT C_USER_PAUSE     : natural := 60_000_000;     --determines pause interval
    CONSTANT C_INIT_DIFF      : natural := 3;           --initial difficulty
    CONSTANT C_STEP_DIFF      : natural := 1;           --step in game difficulty   
    
    TYPE seq_command IS (
    SLEEP,
    GEN,
    PAUSE,
    WRITE,
    DIFF_CLR,
    INCR_STAGE,
    SEQ_CLR,
    COMP,
    DIFF_UP
    );

END PACKAGE dig_top_pckg;

PACKAGE BODY dig_top_pckg IS 

END PACKAGE BODY dig_top_pckg;