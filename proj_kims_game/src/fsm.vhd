----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 06/29/2021 11:24:21 PM
-- Design Name: 
-- Module Name: fsm - rtl
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: Moore type FSM, outputs are cached, containts also input lock and internal timer
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
LIBRARY xil_defaultlib;
USE xil_defaultlib.dig_top_pckg.ALL;


ENTITY fsm IS
    PORT ( 
           clk_in         : IN  std_logic;
           reset_n_in     : IN  std_logic; 
            
           usr_btn          :           IN  std_logic_vector (3 DOWNTO 0);      --user input buttons
           usr_btn_lock     :           OUT std_logic_vector (3 DOWNTO 0);      --user input buttons locked by fsm
           seq_done         :           IN  std_logic;                          --sequence is finished
           lvl_done         :           IN  std_logic;                          --level is finished
           comp_stat        :           IN  std_logic_vector(1 DOWNTO 0);       --comparison status: '11' - match; '00' - no match, else comparison not ready
           status_led_out   :           OUT std_logic_vector (2 DOWNTO 0);      --led status control: green - data match, continue, red - data mismatch, end game
           seq_ctrl         :           OUT seq_command;                        --sequence control
           start_game       :           IN  std_logic                           
           );
END fsm;

ARCHITECTURE rtl OF fsm IS

    TYPE fsm_state IS (
      IDLE,                 --default state
      CLR_DIFF,             --resets difficulty
      CLR_SEQ,              --resets sequence memory, address counter and comparator counter
      GEN_SEQ,              --generate sequence item
      PAUSE_SEQ,            --pause between sequence items, led is lit
      BUFF_STATE,
      PAUSE_DARK,           --pause between sequence items, led is not lit
      WRITE_SEQ,            --write sequence item
      WAIT_BTN,             --wait for user input
      LOCK,                 --lock user input
      COMPARE,              --enable comparison              
      MISS,                 --game over  
      HIT,                  --game continues
      PAUSE,                --give led feedback and wait
      INCR_DIFF             --increase difficulty          
    );
    
    SIGNAL curr_state   :   fsm_state;
    SIGNAL next_state   :   fsm_state;
    
    --SIGNAL lock_input   :   std_logic;      --locks user input on logic high, so that it is stable during operation
    
    SIGNAL pause_end    :   std_logic;      --counter overflow
    SUBTYPE count_int IS natural RANGE 0 TO 2**26; 
    SIGNAL timer_cnt   :   count_int;
    
    --all outputs are cached
    SIGNAL seq_ctrl_i       :   seq_command;
    SIGNAL status_led_out_i :   std_logic_vector (2 DOWNTO 0);
    

BEGIN

    state_reg : PROCESS(clk_in, reset_n_in)
    BEGIN
    
        IF(reset_n_in = '0') THEN
            curr_state <= IDLE;
        ELSIF(rising_edge(clk_in)) THEN
            curr_state <= next_state;
        END IF;
    END PROCESS state_reg;
    
    next_state_proc : PROCESS(curr_state, usr_btn, seq_done, comp_stat, lvl_done, start_game, pause_end)
    BEGIN
    
        next_state <= curr_state;
        
        CASE curr_state IS
            WHEN IDLE                           =>
                IF(start_game = '1') THEN
                    next_state <= CLR_DIFF;          --wake up and clear everything
                ELSE
                    next_state <= IDLE;          
                END IF;
                
            WHEN CLR_DIFF                       =>
                next_state <= CLR_SEQ;
            WHEN CLR_SEQ                        =>
                next_state <= GEN_SEQ;          --trigger the sequence         
            WHEN GEN_SEQ                        =>
                next_state <= PAUSE_SEQ;
            WHEN PAUSE_SEQ                      =>
                IF(pause_end = '1') THEN
                    next_state <= BUFF_STATE;
                ELSE
                    IF(seq_done = '1') THEN
                        next_state <= WAIT_BTN;
                    ELSE
                        next_state <= PAUSE_SEQ;
                    END IF; 
                END IF;
            WHEN BUFF_STATE                     =>
                next_state <= PAUSE_DARK;
            WHEN PAUSE_DARK                      =>
                IF(pause_end = '1') THEN
                    next_state <= WRITE_SEQ;
                ELSE
                    next_state <= PAUSE_DARK;
                END IF;
            WHEN WRITE_SEQ                      =>
                next_state <= GEN_SEQ;
            WHEN WAIT_BTN                       =>
                IF(usr_btn /= "0000") THEN
                    next_state <= LOCK;         --lock input
                ELSE
                    next_state <= WAIT_BTN;     --wait
                END IF;
            WHEN LOCK                           =>
                next_state <= COMPARE;
            WHEN COMPARE                        =>  --compare user input and sequence
                IF(comp_stat = "11") THEN
                    next_state <= HIT;          
                ELSIF(comp_stat = "00") THEN
                    next_state <= MISS;
                ELSE
                    next_state <= COMPARE;
                END IF;
            WHEN MISS                           =>  --game over, reset to play again
                next_state <= MISS;
            WHEN HIT                            =>  
                next_state <= PAUSE;            --display led feedback and wait
            WHEN PAUSE                          =>
                IF(pause_end = '1') THEN    
                    IF(lvl_done = '1') THEN
                        next_state <= INCR_DIFF;    --user has passed this level, increase difficulty a start a new level
                    ELSE
                        next_state <= WAIT_BTN;     --level continues
                    END IF;
                ELSE
                    next_state <= PAUSE;
                END IF;
            WHEN INCR_DIFF                      =>
                next_state <=   CLR_SEQ;
        END CASE;
    
    
    END PROCESS next_state_proc;
    
    output_proc : PROCESS(curr_state)
    BEGIN
    
        CASE curr_state IS
            WHEN IDLE                           =>
                seq_ctrl_i          <=  SLEEP;
                status_led_out_i    <=  "001";
            WHEN CLR_DIFF                       =>
                seq_ctrl_i          <=  DIFF_CLR;
                status_led_out_i    <=  "000";
            WHEN CLR_SEQ                        =>
                seq_ctrl_i          <=  SEQ_CLR;
                status_led_out_i    <=  "000"; 
            WHEN GEN_SEQ                        =>
                seq_ctrl_i          <=  GEN;
                status_led_out_i    <=  "000";
            WHEN PAUSE_SEQ                      =>
                seq_ctrl_i          <=  PAUSE;
                status_led_out_i    <=  "000";
            WHEN BUFF_STATE                     =>
                seq_ctrl_i          <=  SLEEP;
                status_led_out_i    <=  "000";
            WHEN PAUSE_DARK                     =>
                seq_ctrl_i          <=  SLEEP;
                status_led_out_i    <=  "000";
            WHEN WRITE_SEQ                      =>
                seq_ctrl_i          <=  WRITE;
                status_led_out_i    <=  "000";
            WHEN WAIT_BTN                       =>
                seq_ctrl_i          <=  SLEEP;
                status_led_out_i    <=  "000";
            WHEN LOCK                           =>
                seq_ctrl_i          <=  SLEEP;
                status_led_out_i    <=  "000";
            WHEN COMPARE                        =>
                seq_ctrl_i          <=  COMP;
                status_led_out_i    <=  "000";
            WHEN MISS                           =>
                seq_ctrl_i          <=  SLEEP;
                status_led_out_i    <=  "100";
            WHEN HIT                            =>
                seq_ctrl_i          <=  INCR_STAGE;
                status_led_out_i    <=  "010";
            WHEN PAUSE                          =>
                seq_ctrl_i          <=  SLEEP;
                status_led_out_i    <=  "010";
            WHEN INCR_DIFF                      =>
                seq_ctrl_i          <=  DIFF_UP;
                status_led_out_i    <=  "000";           
       END CASE;
    END PROCESS output_proc;
    
    output_cache : PROCESS(clk_in, reset_n_in)      
    BEGIN
        IF(reset_n_in = '0') THEN
            seq_ctrl          <=  SLEEP;
            status_led_out    <=  "000";
        ELSIF(rising_edge(clk_in)) THEN
            seq_ctrl          <=  seq_ctrl_i;
            status_led_out    <=  status_led_out_i;
        END IF;    
    END PROCESS output_cache;
    
    input_lock : PROCESS(clk_in, reset_n_in)        --ensures input stability while comparing
    BEGIN
        IF(reset_n_in = '0') THEN
            usr_btn_lock <= "0000";
        ELSIF(rising_edge(clk_in)) THEN
            IF curr_state = LOCK THEN
                usr_btn_lock <= usr_btn;
            END IF;         
        END IF;    
    END PROCESS input_lock;
    
    pause_timer : PROCESS(clk_in, reset_n_in)        
    BEGIN
        IF(reset_n_in = '0') THEN
            timer_cnt <= C_USER_PAUSE;
            pause_end <= '0';
        ELSIF(rising_edge(clk_in)) THEN
            IF curr_state = CLR_SEQ THEN
                timer_cnt <= C_USER_PAUSE;
                pause_end <= '0';
            ELSE
                IF curr_state = PAUSE_SEQ OR curr_state = PAUSE OR curr_state = PAUSE_DARK THEN
                    IF timer_cnt > 0 THEN
                        timer_cnt <= timer_cnt - 1;                         
                        pause_end <= '0';
                    ELSE
                        timer_cnt <= timer_cnt;
                        pause_end <= '1';
                    END IF;
                ELSE
                    timer_cnt <= C_USER_PAUSE;
                    pause_end <= '0';
                END IF;  
            END IF;       
        END IF;    
    END PROCESS pause_timer;
    
    ASSERT timer_cnt <= C_USER_PAUSE REPORT "Faulty FSM timer value!" SEVERITY error;


END rtl;
