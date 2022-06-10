----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 06/29/2021 08:39:44 PM
-- Design Name: 
-- Module Name: dig_top_mod - structural
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: basic top file
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
LIBRARY xil_defaultlib;
USE xil_defaultlib.dig_top_pckg.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

ENTITY dig_top_mod IS
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
END dig_top_mod;

ARCHITECTURE structural OF dig_top_mod IS

           SIGNAL usr_btn_lock     :           std_logic_vector (3 DOWNTO 0);        --user input buttons locked by fsm
           SIGNAL usr_btn          :           std_logic_vector (3 DOWNTO 0);      --user input buttons
           
           SIGNAL seq_done         :           std_logic;                          --sequence is finished
           SIGNAL lvl_done         :           std_logic;                          --level is finished
           SIGNAL comp_stat        :           std_logic_vector(1 DOWNTO 0);       --comparison status: '11' - match; '00' - no match, else comparison not ready
           SIGNAL seq_ctrl         :           seq_command;                        --sequence control
           SIGNAL start_game       :           std_logic;        
           SIGNAL start_game_i     :           std_logic;
           
           SIGNAL reset_n_i_in     :           std_logic;               

            
    COMPONENT input_debouncer
        PORT ( 
           clk_in         : IN  std_logic;
           reset_n_in     : IN  std_logic; 
            
           usr_btn_c_in :   IN  std_logic_vector (3 DOWNTO 0);
           usr_btn      :   OUT std_logic_vector (3 DOWNTO 0)
           );
    END COMPONENT input_debouncer;   

    COMPONENT sequence_manager
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
    END COMPONENT sequence_manager;
    
    COMPONENT fsm
        PORT ( 
           clk_in           :           IN  std_logic;
           reset_n_in       :           IN  std_logic; 
            
           usr_btn          :           IN  std_logic_vector (3 DOWNTO 0);      --user input buttons
           usr_btn_lock     :           OUT std_logic_vector (3 DOWNTO 0);      --user input buttons locked by fsm
           seq_done         :           IN  std_logic;                          --sequence is finished
           lvl_done         :           IN  std_logic;                          --level is finished
           comp_stat        :           IN  std_logic_vector(1 DOWNTO 0);       --comparison status: '11' - match; '00' - no match, else comparison not ready
           status_led_out   :           OUT std_logic_vector (2 DOWNTO 0);      --led status control: green - data match, continue, red - data mismatch, end game
           seq_ctrl         :           OUT seq_command;                        --sequence control
           start_game       :           IN  std_logic                           
           );
    END COMPONENT fsm;
            

BEGIN

    in_deb : input_debouncer
        PORT MAP (
            clk_in          =>      clk_in,
            reset_n_in      =>      reset_n_i_in,
            usr_btn_c_in    =>      usr_btn_c_in,
            usr_btn         =>      usr_btn  
        );
    
    seq_manag : sequence_manager
        PORT MAP (
            clk_in          =>      clk_in,
            reset_n_in      =>      reset_n_i_in,
            usr_btn_lock    =>      usr_btn_lock,
            seq_done        =>      seq_done,
            lvl_done        =>      lvl_done,
            comp_stat       =>      comp_stat,
            seq_ctrl        =>      seq_ctrl,
            seq_led_out     =>      seq_led_out  
        );
        
    top_fsm : fsm
        PORT MAP (
            clk_in          =>      clk_in,
            reset_n_in      =>      reset_n_i_in,
            usr_btn         =>      usr_btn,
            usr_btn_lock    =>      usr_btn_lock,
            seq_done        =>      seq_done,
            lvl_done        =>      lvl_done,
            comp_stat       =>      comp_stat,
            status_led_out  =>      status_led_out,
            seq_ctrl        =>      seq_ctrl,
            start_game      =>      start_game  
        );   


    double_sync : PROCESS(clk_in, reset_n_i_in) IS            --synchronize start signal by double FF
    BEGIN
        IF(reset_n_i_in = '0') THEN
            start_game_i  <= '0';
            start_game    <= '0';
        ELSIF(rising_edge(clk_in)) THEN
            start_game_i  <= start_game_c_in;
            start_game    <= start_game_i;
        END IF;
    END PROCESS double_sync;
    
    --synthesis translate_off
   
    one_hot_assert : PROCESS(usr_btn)
    
        VARIABLE sum    : natural RANGE 0 TO 4;
        
    BEGIN
    
        FOR i IN 0 TO 3 LOOP
            IF usr_btn(i) = '1' THEN
                sum := sum + 1;
            END IF;
        END LOOP;
    
        ASSERT sum <= 1 REPORT "User input is not one hot encoded!" SEVERITY error;
        
    END PROCESS one_hot_assert;
    
    --synthesis translate_on
    
     reset_n_i_in <= NOT reset_n_in;
 

END structural;
