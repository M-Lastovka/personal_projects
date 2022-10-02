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
-- Description: Basic testbench for verifying just the FFT block, external master is not AXI Stream compliant
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
           SIGNAL sys_clk_in           :           std_logic := '0';
           SIGNAL rst_n_in             :           std_logic := '1';
           CONSTANT C_CLK_PERIOD       :            time := 100 ns;

           --------------------DUT signals---------------------------------------------------------------------------
           
            ---------------------data---------------------------------------------------------------------------------
           
           SIGNAL data_re_0_in         :  std_logic_vector (C_SAMPLE_WDT-1 DOWNTO 0);
           SIGNAL data_im_0_in         :  std_logic_vector (C_SAMPLE_WDT-1 DOWNTO 0);
           SIGNAL data_re_1_in         :  std_logic_vector (C_SAMPLE_WDT-1 DOWNTO 0);
           SIGNAL data_im_1_in         :  std_logic_vector (C_SAMPLE_WDT-1 DOWNTO 0); 
           SIGNAL data_re_0_out        :  std_logic_vector (C_SAMPLE_WDT-1 DOWNTO 0);
           SIGNAL data_im_0_out        :  std_logic_vector (C_SAMPLE_WDT-1 DOWNTO 0);
           SIGNAL data_re_1_out        :  std_logic_vector (C_SAMPLE_WDT-1 DOWNTO 0);
           SIGNAL data_im_1_out        :  std_logic_vector (C_SAMPLE_WDT-1 DOWNTO 0);
           SIGNAL addr_0_in            :  std_logic_vector(C_FFT_SIZE_LOG2-1 DOWNTO 0);
           SIGNAL addr_1_in            :  std_logic_vector(C_FFT_SIZE_LOG2-1 DOWNTO 0);         
           
           ------------------------------control-----------------------------------
           
           SIGNAL busy              :    std_logic;   --fft processor is doing something
           SIGNAL request           :    std_logic;   --request from external master, starts operation
           SIGNAL rx_ready          :    std_logic;   --a sample is ready to be pushed into memory
           SIGNAL push              :    std_logic;   --memory write signal for incoming sample, not used in burst mode
           SIGNAL rx_done           :    std_logic;   --the memory is filled with external data, computation can begin
           SIGNAL rx_val            :    std_logic;   --a sample has been pushed into memory 
           SIGNAL rx_ack            :    std_logic;   --end rx transaction of this sample and move onto another
           SIGNAL comp_done         :    std_logic;   --algorithm has finished
           SIGNAL tx_ready          :    std_logic;   --ready to transmit dft sample
           SIGNAL tx_val            :    std_logic;   --the sample at the output is valid
           SIGNAL tx_ack            :    std_logic;   --end tx transaction of this sample and move onto another
           SIGNAL pop               :    std_logic;   --memory read acknowledge signal, not used in burst mode
           SIGNAL tx_done           :    std_logic;   --all dft samples have been transmited
           SIGNAL all_done          :    std_logic;   --everything is done
           
           SIGNAL overflow_warn            : std_logic;   
           SIGNAL rx_single_ndouble_mode   : std_logic;   
           SIGNAL tx_single_ndouble_mode   : std_logic;   
           SIGNAL burst_mode_en            : std_logic;    
           
           -------------------simulation control---------------------------------------------------------------------
           CONSTANT C_MAX_TRANS_CNT   :          natural := 100;     --number of transaction before the simulation starves
           SIGNAL   trans_cnt         :          natural := 0;       --current transaction count
           SIGNAL   halt              :          std_logic := '0';   --indicates the halting of the simulation
           SIGNAL data_re_out_b       :          std_logic_vector (C_SAMPLE_WDT-1 DOWNTO 0);
           SIGNAL data_im_out_b       :          std_logic_vector (C_SAMPLE_WDT-1 DOWNTO 0);
           TYPE data_arr IS ARRAY(0 TO C_FFT_SIZE -1) OF signed(C_DFT_WDT-1 DOWNTO 0);
           SIGNAL data_amp_arr        :          data_arr;
           SIGNAL data_amp_b          :          signed(C_DFT_WDT-1 DOWNTO 0);
           SIGNAL freq_sig            :          real := real(2.0*3.14/4);
           SIGNAL zero_padd           :          signed(C_DFT_WDT - C_SAMPLE_WDT DOWNTO 0) := (OTHERS => '0');
           
           ------------------user variables--------------------------------------------------------------------------


           TYPE input_arr IS ARRAY(0 TO C_FFT_SIZE-1) OF std_logic_vector(C_SAMPLE_WDT-1 DOWNTO 0);
           SIGNAL input_memory_re     :              input_arr;
           SIGNAL input_memory_im     :              input_arr;
           SIGNAL out_amp             :              integer;
           
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

            
    COMPONENT fft_dig_top
        PORT ( 
           -----------------------clocks and resets---------------------------------
           
           sys_clk_in         : IN  std_logic;
           rst_n_in           : IN  std_logic;
            
           -------------------------------data-------------------------------------
           
           data_re_0_in         :   IN   std_logic_vector (C_SAMPLE_WDT-1 DOWNTO 0);
           data_im_0_in         :   IN   std_logic_vector (C_SAMPLE_WDT-1 DOWNTO 0);
           data_re_1_in         :   IN   std_logic_vector (C_SAMPLE_WDT-1 DOWNTO 0);
           data_im_1_in         :   IN   std_logic_vector (C_SAMPLE_WDT-1 DOWNTO 0);
           data_re_0_out        :   OUT  std_logic_vector (C_SAMPLE_WDT-1 DOWNTO 0);
           data_im_0_out        :   OUT  std_logic_vector (C_SAMPLE_WDT-1 DOWNTO 0);
           data_re_1_out        :   OUT  std_logic_vector (C_SAMPLE_WDT-1 DOWNTO 0);
           data_im_1_out        :   OUT  std_logic_vector (C_SAMPLE_WDT-1 DOWNTO 0); 
           
           -------------------------------address-----------------------------------
           
           addr_0_in          :   IN   std_logic_vector(C_FFT_SIZE_LOG2-1 DOWNTO 0);
           addr_1_in          :   IN   std_logic_vector(C_FFT_SIZE_LOG2-1 DOWNTO 0);                      
           
           ------------------------------handshake control--------------------------
           
           busy              : OUT std_logic;   --fft processor is doing something
           request           : IN  std_logic;   --request from external master, starts operation
           rx_ready          : OUT std_logic;   --a sample is ready to be pushed into memory
           rx_val            : OUT std_logic;   --a sample has been pushed into memory 
           rx_ack            : IN  std_logic;   --end rx transaction of this sample and move onto another           :
           push              : IN  std_logic;   --memory write signal for incoming sample, not used in burst mode
           rx_done           : IN  std_logic;   --the memory is filled with external data, computation can begin
           comp_done         : OUT std_logic;   --algorithm has finished
           tx_ready          : OUT std_logic;   --ready to transmit dft sample
           tx_val            : OUT std_logic;   --the sample at the output is valid
           tx_ack            : IN  std_logic;   --end tx transaction of this sample and move onto another
           pop               : IN  std_logic;   --memory read acknowledge signal, not used in burst mode
           tx_done           : IN  std_logic;   --all dft samples have been transmited
           all_done          : OUT std_logic;    --everything is done
           
           ----------------------------status & IF config control---------------------
           
           overflow_warn            : OUT std_logic;   --somewhere in the computation, an addition overflow has ocurred, result may be unreliable (clipped)
           rx_single_ndouble_mode   : IN  std_logic;   -- = '1' - input samples are transmited one at a time through port 0
                                                       -- = '0' - input samples are transmited two at a time 
           tx_single_ndouble_mode   : IN  std_logic;   -- = '1' - output samples are transmited one at a time through port 0
                                                       -- = '0' - output samples are transmited two at a time
           burst_mode_en            : IN  std_logic    --burst mode enable, reserved for future use                                                                                                              

           
           
           );
    END COMPONENT fft_dig_top;   


BEGIN

    dut : fft_dig_top
        PORT MAP (
            sys_clk_in              =>        sys_clk_in,
            rst_n_in                =>        rst_n_in,
            data_re_0_in            =>        data_re_0_in, 
            data_im_0_in            =>        data_im_0_in, 
            data_re_1_in            =>        data_re_1_in, 
            data_im_1_in            =>        data_im_1_in, 
            data_re_0_out           =>        data_re_0_out,
            data_im_0_out           =>        data_im_0_out,
            data_re_1_out           =>        data_re_1_out,
            data_im_1_out           =>        data_im_1_out,
            addr_0_in               =>        addr_0_in,
            addr_1_in               =>        addr_1_in,
            busy                    =>        busy,
            request                 =>        request,
            rx_ready                =>        rx_ready,
            rx_val                  =>        rx_val,
            rx_ack                  =>        rx_ack,
            push                    =>        push,
            rx_done                 =>        rx_done,
            comp_done               =>        comp_done,
            tx_ready                =>        tx_ready,
            tx_val                  =>        tx_val,
            tx_ack                  =>        tx_ack,
            pop                     =>        pop,
            tx_done                 =>        tx_done,
            all_done                =>        all_done,
            overflow_warn           =>        overflow_warn,
            rx_single_ndouble_mode  =>        rx_single_ndouble_mode,
            tx_single_ndouble_mode  =>        tx_single_ndouble_mode,
            burst_mode_en           =>        burst_mode_en
        );
    
    clock_gen : PROCESS 
    BEGIN
        IF halt = '0' THEN
            WAIT FOR C_CLK_PERIOD/2;
            sys_clk_in <= '1';
            WAIT FOR C_CLK_PERIOD/2;
            sys_clk_in <= '0';
        ELSE
            WAIT;
        END IF;
        
    END PROCESS clock_gen;
    
    reset_gen : PROCESS
    BEGIN
        WAIT FOR rand_time_val(C_CLK_PERIOD,C_CLK_PERIOD*3);
        rst_n_in <= '0';
        WAIT FOR rand_time_val(C_CLK_PERIOD*10,C_CLK_PERIOD*100);
        rst_n_in <= '1';
        WAIT;
    END PROCESS reset_gen;


    user_agent : PROCESS
        
        VARIABLE data_re_v : std_logic_vector(C_SAMPLE_WDT-1 DOWNTO 0);
        VARIABLE data_im_v : std_logic_vector(C_SAMPLE_WDT-1 DOWNTO 0);
        
    BEGIN
        
        request <= '0';
        rx_done <= '0';
        tx_done <= '0';
        addr_0_in    <= std_logic_vector(to_signed(0, C_FFT_SIZE_LOG2));
        addr_1_in    <= std_logic_vector(to_signed(1, C_FFT_SIZE_LOG2));
                
        WAIT UNTIL rising_edge(rst_n_in); 
        
        LOOP        
            IF halt = '0' THEN
                
                WAIT FOR rand_time_val(C_CLK_PERIOD*20,C_CLK_PERIOD*30);
                
                request <= '1';
                rx_single_ndouble_mode <= '0';
                tx_single_ndouble_mode <= '0';
                
                
--                --non burst mode
--                burst_mode_en <= '0';
--                FOR i IN 0 TO (C_FFT_SIZE)/2 - 1 LOOP     --push data
                
--                    WAIT UNTIL rx_ready = '1';
--                    WAIT UNTIL rising_edge(sys_clk_in);
--                    rx_ack <= '0';
--                    WAIT FOR 0 ns;
--                    --data_re_v :=  std_logic_vector(to_signed(integer(real(255)*sin(real(real(i)/real(10)))), C_SAMPLE_WDT) + to_signed(integer(real(128)*sin(real(real(i)/real(20)))), C_SAMPLE_WDT));--std_logic_vector(to_signed(rand_int(0,2**C_SAMPLE_WDT - 1), C_SAMPLE_WDT));
--                    --data_im_v :=  std_logic_vector(to_signed(0, C_SAMPLE_WDT));--std_logic_vector(to_signed(rand_int(0,2**C_SAMPLE_WDT - 1), C_SAMPLE_WDT));
--                    addr_0_in    <= std_logic_vector(to_signed(2*i, C_FFT_SIZE_LOG2));
--                    addr_1_in    <= std_logic_vector(to_signed(2*i+1, C_FFT_SIZE_LOG2));
--                    data_re_0_in <= std_logic_vector(to_signed(integer(real(255)*sin(real(real(2*i)/real(10)))), C_SAMPLE_WDT) + to_signed(integer(real(128)*sin(real(real(i)/real(20)))), C_SAMPLE_WDT));
--                    data_im_0_in <= std_logic_vector(to_signed(0, C_SAMPLE_WDT));--std_logic_vector(to_signed(rand_int(0,2**C_SAMPLE_WDT - 1), C_SAMPLE_WDT));;
--                    data_re_1_in <= std_logic_vector(to_signed(integer(real(255)*sin(real(real(2*i+1)/real(10)))), C_SAMPLE_WDT) + to_signed(integer(real(128)*sin(real(real(i)/real(20)))), C_SAMPLE_WDT));
--                    data_im_1_in <= std_logic_vector(to_signed(0, C_SAMPLE_WDT));--std_logic_vector(to_signed(rand_int(0,2**C_SAMPLE_WDT - 1), C_SAMPLE_WDT));;
--                    --input_memory_re(i) <= data_re_v;
--                    --input_memory_im(i) <= data_im_v; 
--                    WAIT FOR 0 ns;
--                    push <= '1';
--                    WAIT UNTIL rx_val = '1';
--                    WAIT FOR 0 ns;
--                    rx_ack <= '1';
--                    push <= '0';
                        
--                END LOOP;
                
                --burst mode
                burst_mode_en <= '1';
                WAIT UNTIL rx_ready = '1';
                FOR i IN 0 TO (C_FFT_SIZE)/2 - 1 LOOP     --push data
                    
                    WAIT UNTIL rising_edge(sys_clk_in);
                    WAIT FOR 0 ns;
                    addr_0_in    <= std_logic_vector(to_signed(2*i, C_FFT_SIZE_LOG2));
                    addr_1_in    <= std_logic_vector(to_signed(2*i+1, C_FFT_SIZE_LOG2));
                    IF i < 2**5 THEN
                        data_re_0_in <= std_logic_vector(to_signed(2**11, C_SAMPLE_WDT));
                        data_im_0_in <= std_logic_vector(to_signed(0, C_SAMPLE_WDT));
                        data_re_1_in <= std_logic_vector(to_signed(2**11, C_SAMPLE_WDT));
                        data_im_1_in <= std_logic_vector(to_signed(0, C_SAMPLE_WDT));
                    ELSE
                        data_re_0_in <= std_logic_vector(to_signed(0, C_SAMPLE_WDT));
                        data_im_0_in <= std_logic_vector(to_signed(0, C_SAMPLE_WDT));
                        data_re_1_in <= std_logic_vector(to_signed(0, C_SAMPLE_WDT));
                        data_im_1_in <= std_logic_vector(to_signed(0, C_SAMPLE_WDT));
                    END IF;
--                    data_re_0_in <= std_logic_vector(to_signed(integer(real(2**11-1)*sin(real(real(2*i)*freq_sig))), C_SAMPLE_WDT));
--                    data_im_0_in <= std_logic_vector(to_signed(0, C_SAMPLE_WDT));
--                    data_re_1_in <= std_logic_vector(to_signed(integer(real(2**11-1)*sin(real(real(2*i+1)*freq_sig))), C_SAMPLE_WDT));
--                    data_im_1_in <= std_logic_vector(to_signed(0, C_SAMPLE_WDT));
                                                                                 
 
                
                END LOOP;
                
                rx_done <= '1'; 
                WAIT UNTIL rx_ready = '0';
                WAIT FOR 0 ns;         
                addr_0_in    <= std_logic_vector(to_signed(0, C_FFT_SIZE_LOG2));
                addr_1_in    <= std_logic_vector(to_signed(1, C_FFT_SIZE_LOG2));     
                WAIT UNTIL comp_done = '1';
                
                rx_done <= '0';
                
                
--                --non burst mode
--                FOR i IN 0 TO (C_FFT_SIZE/2) -1 LOOP     --pop data
                    
--                    WAIT UNTIL tx_ready = '1';
--                    WAIT UNTIL rising_edge(sys_clk_in);
--                    tx_ack <= '0';
--                    addr_0_in    <= std_logic_vector(to_signed(2*i, C_FFT_SIZE_LOG2));
--                    addr_1_in    <= std_logic_vector(to_signed(2*i+1, C_FFT_SIZE_LOG2));
--                    pop <= '1';
--                    WAIT UNTIl tx_val = '1';
--                    WAIT FOR 0 ns;
--                    WAIT FOR 0 ns;
--                    tx_ack <= '1';
--                    pop <= '0';
                    
--                END LOOP;

                --burst mode
                WAIT UNTIL tx_ready = '1';
                FOR i IN 0 TO (C_FFT_SIZE/2) -1 LOOP     --pop data
                                
                    WAIT UNTIL rising_edge(sys_clk_in);
                    WAIT FOR 0 ns;
                    addr_0_in    <= std_logic_vector(to_signed(2*i, C_FFT_SIZE_LOG2));
                    addr_1_in    <= std_logic_vector(to_signed(2*i+1, C_FFT_SIZE_LOG2));
                    --compute amplitude
                    data_amp_arr(2*i)   <= signed(data_re_0_out)*signed(data_re_0_out) + signed(data_im_0_out)*signed(data_im_0_out);
                    data_amp_arr(2*i+1) <= signed(data_re_1_out)*signed(data_re_1_out) + signed(data_im_1_out)*signed(data_im_1_out);
                    
                END LOOP;

                tx_done <= '1';
                FOR i IN 0 TO C_FFT_SIZE-1 LOOP     --display amplitude of computed DFT
                                
                    WAIT FOR 0 ns;
                    data_amp_b <= data_amp_arr(i);
 
                END LOOP;
                WAIT UNTIL rising_edge(sys_clk_in); 
                request <= '0';
                trans_cnt <= trans_cnt + 1;   
                WAIT UNTIL busy = '0';   
                tx_done <= '0'; 
                

       
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
