----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 07/04/2021 04:21:46 PM
-- Design Name: 
-- Module Name: tb_top - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments: basic testbench
-- 
----------------------------------------------------------------------------------



LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL.ALL;
LIBRARY work;
USE work.dig_top_pckg.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;fdsaf

ENTITY tb_top IS

END tb_top;

ARCHITECTURE behavioral OF tb_top IS

            
           --------------------clocks and resets--------------------------------------------------------------------- 
           SIGNAL clk_in           :           std_logic := '0';
           SIGNAL reset_n_in       :           std_logic := '0';
           CONSTANT C_CLK_PERIOD   :            time := 100 ns;

           --------------------DUT signals---------------------------------------------------------------------------
           SIGNAL usr_btn_c_in     :           std_logic_vector (3 DOWNTO 0) := "0000";
           SIGNAL start_game_c_in  :           std_logic := '0';
           
           SIGNAL status_led_out   :            std_logic_vector (2 DOWNTO 0);
           SIGNAL seq_led_out      :            std_logic_vector (3 DOWNTO 0);
           
           -------------------simulation control---------------------------------------------------------------------
           CONSTANT C_MAX_TRANS_CNT:            natural := 100;     --number of transaction before the simulation starves
           SIGNAL   trans_cnt      :            natural := 0;       --current transaction count
           SIGNAL   halt             :            std_logic := '0';   --indicates the halting of the simulation
           
           ------------------user variables--------------------------------------------------------------------------
           SIGNAL monitor_turn        :            std_logic := '1';     --determines if it is user turn to observe
           SIGNAL agent_turn          :            std_logic := '0';     --determines if it is user turn to play
           TYPE observed_arr IS ARRAY(0 TO 255) OF std_logic_vector(3 DOWNTO 0);
           SIGNAL seq_memory       :              observed_arr;
           SIGNAL curr_diff        :            natural := C_INIT_DIFF;

           
           SHARED VARIABLE seed1, seed2    :            integer := 999;
           
           --utility function definitions
           
           IMPURE FUNCTION rand_time_val(min_val, max_val : time; unit : time := ns) RETURN time IS
           
                VARIABLE r, r_scaled : real;
           
           BEGIN
           
                ASSERT min_val < max_val REPORT "invalid bounds" SEVERITY failure;
                
                uniform(seed1,seed2,r);
                r_scaled := r*(real(max_val/unit) - real(min_val/unit)) + real(min_val/unit);
                RETURN real(r_scaled)*unit;
           
           END FUNCTION;
           
           IMPURE FUNCTION rand_int(min_v, max_v : integer) RETURN integer IS
           
                VARIABLE r : real;
                
           BEGIN
           
                uniform(seed1, seed2, r);
                RETURN integer(round(r * real(max_v - min_v + 1) + real(min_v) - 0.5));
                
           END FUNCTION; 

            
    COMPONENT dig_top_mod
        PORT ( 
           ---------clocks and resets----------------------------------------------
           clk_in         : IN  std_logic;
           reset_n_in     : IN  std_logic;
            
           --------user inputs-----------------------------------------------------
           usr_btn_c_in         :   IN  std_logic_vector (3 DOWNTO 0);
           start_game_c_in      :   IN  std_logic;                           
           
           -------status and signal outputs----------------------------------------
           status_led_out : OUT std_logic_vector (2 DOWNTO 0);
           seq_led_out    : OUT std_logic_vector (3 DOWNTO 0)
           
           );
    END COMPONENT dig_top_mod;   


BEGIN

    dut : dig_top_mod
        PORT MAP (
            clk_in              =>      clk_in,
            reset_n_in          =>      reset_n_in,
            usr_btn_c_in        =>      usr_btn_c_in,
            start_game_c_in     =>      start_game_c_in,
            status_led_out      =>      status_led_out,
            seq_led_out         =>      seq_led_out
        );
    
    clock_gen : PROCESS 
    BEGIN
        IF halt = '0' THEN
            WAIT FOR C_CLK_PERIOD/2;
            clk_in <= '1';
            WAIT FOR C_CLK_PERIOD/2;
            clk_in <= '0';
        ELSE
            WAIT;
        END IF;
        
    END PROCESS clock_gen;
    
    reset_gen : PROCESS
    BEGIN
        WAIT FOR rand_time_val(C_CLK_PERIOD,C_CLK_PERIOD*3);
        reset_n_in <= '1';
        WAIT FOR rand_time_val(C_CLK_PERIOD*10,C_CLK_PERIOD*100);
        reset_n_in <= '0';
        WAIT;
    END PROCESS reset_gen;
    
    user_monitor : PROCESS
    BEGIN
    
        WAIT UNTIL rising_edge(reset_n_in);
        
        LOOP        
            IF halt = '0' THEN
                               
                WAIT FOR rand_time_val(C_CLK_PERIOD*10,C_CLK_PERIOD*100);
                
                start_game_c_in <= '1';
                
                FOR i IN 1 TO curr_diff LOOP
                    WAIT UNTIL seq_led_out'EVENT AND seq_led_out /= "0000";
                    seq_memory(i) <= seq_led_out;
                END LOOP;
                         
                curr_diff <= curr_diff + C_STEP_DIFF;      
                monitor_turn <= '0';               --time for the user to play
                WAIT FOR 1 ns;
                WAIT UNTIL agent_turn = '0';
                monitor_turn <= '1';
            ELSE
                start_game_c_in <= '0';
                WAIT;       --simulation is starved
            END IF;
        
        END LOOP;
        
    
    END PROCESS user_monitor;
    
    user_agent : PROCESS
        
        VARIABLE r_bounce  : integer;       --how many times will input bounce
        VARIABLE r_btn     : integer;       --which faulty button will be pressed
        
    BEGIN
    
        WAIT UNTIL rising_edge(reset_n_in); 
        
        LOOP        
            IF halt = '0' THEN
                
                WAIT UNTIL monitor_turn <= '0';
                agent_turn <= '1';
                
                WAIT FOR rand_time_val(C_CLK_PERIOD*6_000,C_CLK_PERIOD*8_000);
                
                r_bounce := rand_int(0,10);
                r_btn    := rand_int(0,3);
                
                FOR i IN 1 TO curr_diff-1 LOOP
                
                    FOR k IN 0 TO r_bounce LOOP        --simulate bouncy user input
                        
                        usr_btn_c_in <= seq_memory(i);
                        WAIT FOR rand_time_val(1 us,10 us);
                        usr_btn_c_in <= "0000";  
                        WAIT FOR rand_time_val(200 ns,2 us);
                        
                    END LOOP; 
                    
                    usr_btn_c_in <= seq_memory(i);
                    WAIT FOR rand_time_val(200 us,300 us);
                    usr_btn_c_in <= "0000";
                    IF i /= curr_diff-1 THEN
                        WAIT FOR rand_time_val(300 us,500 us);
                    END IF;
                    WAIT FOR 0 ns;
                    
                END LOOP;
                               
                agent_turn <= '0';                   --time for user to observe sequence
                trans_cnt <= trans_cnt + 1;
            ELSE
                WAIT;       --simulation is starved
            END IF;
        
        END LOOP;
        
    END PROCESS user_agent;
    
    starvation : PROCESS(trans_cnt)
    BEGIN
        IF trans_cnt = C_MAX_TRANS_CNT THEN
            halt <= '1';
        END IF;
    END PROCESS starvation;        
    
    
    
    
 

END behavioral;