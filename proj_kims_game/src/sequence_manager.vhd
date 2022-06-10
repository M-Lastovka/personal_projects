----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 07/03/2021 05:26:41 PM
-- Design Name: 
-- Module Name: sequence_manager - rtl
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: generates and saves sequence, includes comparator
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE ieee.numeric_std.ALL;
LIBRARY xil_defaultlib;
USE xil_defaultlib.dig_top_pckg.ALL;


ENTITY sequence_manager IS
    PORT ( 
           clk_in         : IN  std_logic;
           reset_n_in     : IN  std_logic; 
            
           usr_btn_lock     :           IN std_logic_vector (3 DOWNTO 0);        --user input buttons locked by fsm
           seq_done         :           OUT  std_logic;                          --sequence is finished
           lvl_done         :           OUT  std_logic;                          --level is finished
           comp_stat        :           OUT  std_logic_vector(1 DOWNTO 0);       --comparison status: '11' - match; '00' - no match, else comparison not ready
           seq_ctrl         :           IN   seq_command;                        --sequence control
           seq_led_out      :           OUT  std_logic_vector(3 DOWNTO 0)        --display the sequence through these signals
           );
END sequence_manager;

ARCHITECTURE rtl OF sequence_manager IS

    ------------------random binary sequence generator-----------------------------------------------

    SIGNAL  seq_led_c_out   :   std_logic_vector(3 DOWNTO 0);           --decoder output to be cached
    SIGNAL  lsfr_polyn_curr :   std_logic_vector(1 TO 9);               --LSFR counter full output
    SIGNAL  lsfr_polyn_next :   std_logic_vector(1 TO 9);               
    SIGNAL  seq_bin         :   std_logic_vector(1 DOWNTO 0);           --generated sequence item in binary
    -------------------control counters--------------------------------------------------------------
    
    SUBTYPE count_addr IS natural RANGE 0 TO 2**8-1;                   --address generator counter
    SIGNAL  addr_cnt:   count_addr;  
    
    SUBTYPE count_diff IS natural RANGE 0 TO 2**8-1;                   --difficulty counter
    SIGNAL  diff_cnt:   count_diff;  
    
    SUBTYPE count_comp IS natural RANGE 0 TO 2**8-1;                   --comparator counter
    SIGNAL  comp_cnt:   count_comp;  
    
    ------------------single port RAM---------------------------------------------------------------- 
    
    TYPE ram_data_array IS ARRAY(0 TO 255) OF std_logic_vector(1 DOWNTO 0);
    SIGNAL ram_content  : ram_data_array;
    SIGNAL ram_wr_addr  : std_logic_vector(7 DOWNTO 0);
    SIGNAL ram_rd_addr  : std_logic_vector(7 DOWNTO 0);
    SIGNAL ram_din      : std_logic_vector(1 DOWNTO 0);
    SIGNAL ram_dout     : std_logic_vector(1 DOWNTO 0);
    
    ----------------------other----------------------------------------------------------------------
    
    SIGNAL seq_ram_c    : std_logic_vector(3 DOWNTO 0);                --decoded ram output
    
BEGIN

    seq_gen : PROCESS(clk_in, reset_n_in, lsfr_polyn_curr) 
    BEGIN
         IF(reset_n_in = '0') THEN
            lsfr_polyn_curr <= (1 => '1',OTHERS => '0');
         ELSIF(rising_edge(clk_in)) THEN
            lsfr_polyn_curr <= lsfr_polyn_next;
         END IF;
         
         --feedback loop
         lsfr_polyn_next <= (lsfr_polyn_curr(9) XOR lsfr_polyn_curr(5)) & lsfr_polyn_curr(1 TO 8);   --Fibonacci LSFR, period of 511
    END PROCESS seq_gen;
    
    seq_lock : PROCESS(clk_in, reset_n_in) 
    BEGIN
         IF(reset_n_in = '0') THEN
            seq_bin <= "00";
         ELSIF(rising_edge(clk_in)) THEN
            IF seq_ctrl = GEN THEN
                seq_bin <= lsfr_polyn_curr(1 TO 2);
            END IF;
         END IF;
    END PROCESS seq_lock;
    
    dec_proc : PROCESS(seq_bin)  --decoder that converts the polynom to random led output
    BEGIN
        CASE(seq_bin) IS
            WHEN "00"                       =>
                seq_led_c_out <= "0001";
            WHEN "01"                       =>
                seq_led_c_out <= "0010";
            WHEN "10"                       =>
                seq_led_c_out <= "0100";
            WHEN "11"                       =>
                seq_led_c_out <= "1000";
            WHEN OTHERS                     =>
                seq_led_c_out <= "0000";
        END CASE;
    END PROCESS dec_proc;
    
    seq_led_out_cache : PROCESS(clk_in, reset_n_in)
    BEGIN
        IF(reset_n_in = '0') THEN
            seq_led_out <= "0000";
        ELSIF(rising_edge(clk_in)) THEN
            IF(seq_ctrl = PAUSE) THEN
              seq_led_out <= seq_led_c_out;
            ELSE
              seq_led_out <= "0000";
            END IF;
        END IF;
    END PROCESS seq_led_out_cache;
    
    seq_storage : PROCESS(clk_in, ram_rd_addr)
    BEGIN
    
        IF(rising_edge(clk_in)) THEN
            IF(seq_ctrl = WRITE) THEN
                ram_content(to_integer(unsigned(ram_wr_addr))) <= ram_din;
            END IF;
        END IF;
        
        ram_dout <= ram_content(to_integer(unsigned(ram_rd_addr)));
    
    END PROCESS seq_storage;
    
    dec_proc_ram : PROCESS(ram_dout)  --decoder for the ram output
    BEGIN
        CASE(ram_dout) IS
            WHEN "00"                   =>
                seq_ram_c <= "0001";
            WHEN "01"                   =>
                seq_ram_c <= "0010";
            WHEN "10"                   =>
                seq_ram_c <= "0100";
            WHEN "11"                   =>
                seq_ram_c <= "1000";
            WHEN OTHERS                 =>
                seq_ram_c <= "0000";
        END CASE;
    END PROCESS dec_proc_ram;
    
    comparator : PROCESS(clk_in, reset_n_in) --compare sequence item and user input
    BEGIN
        IF(rising_edge(clk_in)) THEN
             IF(seq_ctrl = COMP) THEN
                IF(seq_ram_c = usr_btn_lock) THEN
                    comp_stat <= "11";
                ELSE
                    comp_stat <= "00";
                END IF;
             END IF;
        END IF;
    END PROCESS comparator;
    
    diff_counter : PROCESS(clk_in, reset_n_in) --increments difficulty
    BEGIN
        IF(reset_n_in = '0') THEN
            diff_cnt <= C_INIT_DIFF;
        ELSIF(rising_edge(clk_in)) THEN
            IF seq_ctrl = DIFF_CLR THEN
                diff_cnt <= C_INIT_DIFF;
            ELSIF seq_ctrl = DIFF_UP THEN
                diff_cnt <= diff_cnt + C_STEP_DIFF;
            ELSE
                diff_cnt <= diff_cnt;         
            END IF;       
        END IF;    
    END PROCESS diff_counter;
    
    addr_counter : PROCESS(clk_in, reset_n_in) --address generator for saving the sequence in ram
    BEGIN
        IF(reset_n_in = '0') THEN
            seq_done <= '0';
            addr_cnt <= 0;
        ELSIF(rising_edge(clk_in)) THEN
                IF seq_ctrl = SEQ_CLR THEN
                    seq_done <= '0';
                    addr_cnt <= 0;
                ELSIF seq_ctrl = GEN THEN
                    IF addr_cnt >= diff_cnt THEN    --TODO: inspect this
                        seq_done <= '1';
                        addr_cnt <= addr_cnt;
                    ELSE         
                        seq_done <= '0';
                        addr_cnt <= addr_cnt + 1;       --TODO: this could change
                    END IF;
            --    ELSE
            --        seq_done <= '0';
            --        addr_cnt <= addr_cnt;         
                END IF;       
        END IF;    
    END PROCESS addr_counter;
    
    comp_counter : PROCESS(clk_in, reset_n_in)  
    BEGIN
        IF(reset_n_in = '0') THEN
            lvl_done <= '0';
            comp_cnt <= 1;
        ELSIF(rising_edge(clk_in)) THEN
                IF seq_ctrl = SEQ_CLR THEN
                    lvl_done <= '0';
                    comp_cnt <=  1;
                ELSIF seq_ctrl = INCR_STAGE THEN
                    IF comp_cnt >= diff_cnt THEN    --TODO: inspect this
                        lvl_done <= '1';
                        comp_cnt <=  comp_cnt;
                    ELSE         
                        lvl_done <= '0';
                        comp_cnt <= comp_cnt + 1;       --TODO: this could change
                    END IF;
         --       ELSE
         --         lvl_done <= '0';
         --         comp_cnt <= comp_cnt;         
                END IF;       
        END IF;    
    END PROCESS comp_counter;
    
    --simple signal assignement
    ram_din        <= seq_bin;
    ram_wr_addr    <= std_logic_vector(to_unsigned(addr_cnt,8));
    ram_rd_addr    <= std_logic_vector(to_unsigned(comp_cnt,8));
    
END rtl;