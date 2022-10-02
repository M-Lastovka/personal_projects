----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 06/25/2022 04:42:10 PM
-- Design Name: 
-- Module Name: spectral_analyzer_tb_top - behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
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
--LIBRARY work;
--USE work.dig_top_pckg.ALL;
LIBRARY xil_defaultlib;
USE xil_defaultlib.dig_top_pckg.ALL;


ENTITY spectral_analyzer_tb_top IS
END spectral_analyzer_tb_top;

ARCHITECTURE behavioral OF spectral_analyzer_tb_top IS


    --------------------DUT signals----------------------------------------------------------------------------

    -----------------------clocks and resets---------------------------------

     SIGNAL sys_clk_in     :  std_logic := '0';
     SIGNAL sys_clk_div_in :  std_logic := '0';
     SIGNAL rst_n_in       :  std_logic := '1';
     CONSTANT C_CLK_PERIOD       :            time := 100 ns;

    -----------------------interrupts to PS----------------------------------
       
     SIGNAL IRQ_FFT_DONE         :  std_logic;

    ------------------AXI stream memory to PL---------------------------

     SIGNAL S_AXIS_TREADY  : std_logic;                                       --slave ready
     SIGNAL S_AXIS_TDATA   : std_logic_vector(C_AXIS_DATA_WDT-1 DOWNTO 0);     --data in
     SIGNAL S_AXIS_TSTRB   : std_logic_vector((C_AXIS_DATA_WDT/8)-1 DOWNTO 0); --byte qualifier, not used
     SIGNAL S_AXIS_TLAST   : std_logic;                                        --indicates boundary of last packet
     SIGNAL S_AXIS_TVALID  : std_logic;                                        --master initiate

    ------------------AXI stream PL to memory---------------------------

     SIGNAL M_AXIS_TREADY   : std_logic;                                        --slave ready
     SIGNAL M_AXIS_TDATA    : std_logic_vector(C_AXIS_DATA_WDT-1 DOWNTO 0);     --data in
     SIGNAL M_AXIS_TSTRB    : std_logic_vector((C_AXIS_DATA_WDT/8)-1 DOWNTO 0); --byte qualifier, not used
     SIGNAL M_AXIS_TLAST    : std_logic;                                        --indicates boundary of last packet
     SIGNAL M_AXIS_TVALID	: std_logic;

     -------------------simulation control---------------------------------------------------------------------
     CONSTANT C_MAX_TRANS_CNT   :          natural := 100;     --number of transaction before the simulation starves
     SIGNAL   trans_cnt         :          natural := 0;       --current transaction count
     SIGNAL   halt              :          std_logic := '0';   --indicates the halting of the simulation
     SIGNAL   data_re_out_b     :          std_logic_vector (C_SAMPLE_WDT-1 DOWNTO 0);
     SIGNAL   data_im_out_b     :          std_logic_vector (C_SAMPLE_WDT-1 DOWNTO 0);
     TYPE data_arr IS ARRAY(0 TO C_FFT_SIZE -1) OF real;
     TYPE data_arr_raw IS ARRAY(0 TO 2*C_FFT_SIZE -1) OF std_logic_vector(C_AXIS_DATA_WDT-1 DOWNTO 0);
     SIGNAL data_amp_arr        :          data_arr;
     SIGNAL data_raw_arr        :          data_arr_raw;
     SIGNAL data_amp_b          :          signed(C_DFT_WDT-1 DOWNTO 0);
     SIGNAL freq_sig            :          real := real(2.0*3.14/8);
     CONSTANT C_PROB_DEASSERT   :          natural := 99;
     SIGNAL zero_padd           :          signed(C_DFT_WDT - C_SAMPLE_WDT DOWNTO 0) := (OTHERS => '0');

     TYPE input_arr IS ARRAY(0 TO C_FFT_SIZE-1) OF std_logic_vector(C_SAMPLE_WDT-1 DOWNTO 0);
     SIGNAL input_memory_re     :              input_arr;
     SIGNAL input_memory_im     :              input_arr;
     SIGNAL out_amp             :              integer;
     SIGNAL m_is_writing        :              std_logic := '0';
     SIGNAL s_is_reading        :              std_logic := '0';
     
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
    
    COMPONENT spectral_analyzer_pl_wrapper IS
         PORT ( 
               -----------------------clocks and resets---------------------------------
                  
               sys_clk_in         : IN  std_logic;
               rst_n_in           : IN  std_logic;
       
               -----------------------interrupts to PS----------------------------------
       
               IRQ_FFT_DONE       : OUT std_logic;
               
               -----------------------AXI stream memory to PL---------------------------
               
               S_AXIS_TREADY	: OUT std_logic;                                       --slave ready
               S_AXIS_TDATA	    : IN std_logic_vector(C_AXIS_DATA_WDT-1 DOWNTO 0);     --data in
               S_AXIS_TSTRB	    : IN std_logic_vector((C_AXIS_DATA_WDT/8)-1 DOWNTO 0); --byte qualifier, not used
               S_AXIS_TLAST	    : IN std_logic;                                        --indicates boundary of last packet
               S_AXIS_TVALID	: IN std_logic;                                        --master initiate
               
               -----------------------AXI stream PL to memory---------------------------
               
               M_AXIS_TREADY	: IN  std_logic;                                        --slave ready
               M_AXIS_TDATA	    : OUT std_logic_vector(C_AXIS_DATA_WDT-1 DOWNTO 0);     --data in
               M_AXIS_TSTRB	    : OUT std_logic_vector((C_AXIS_DATA_WDT/8)-1 DOWNTO 0); --byte qualifier, not used
               M_AXIS_TLAST	    : OUT std_logic;                                        --indicates boundary of last packet
               M_AXIS_TVALID	: OUT std_logic

         );
    END COMPONENT spectral_analyzer_pl_wrapper;

BEGIN

    dut : spectral_analyzer_pl_wrapper
    PORT MAP (
        sys_clk_in      =>  sys_clk_in,     
        rst_n_in        =>  rst_n_in,
        IRQ_FFT_DONE    =>  IRQ_FFT_DONE,
        S_AXIS_TREADY	=>  S_AXIS_TREADY,
        S_AXIS_TDATA	=>  S_AXIS_TDATA,
        S_AXIS_TSTRB	=>  S_AXIS_TSTRB,
        S_AXIS_TLAST	=>  S_AXIS_TLAST,
        S_AXIS_TVALID	=>  S_AXIS_TVALID,
        M_AXIS_TREADY	=>  M_AXIS_TREADY,
        M_AXIS_TDATA	=>  M_AXIS_TDATA,
        M_AXIS_TSTRB	=>  M_AXIS_TSTRB,
        M_AXIS_TLAST	=>  M_AXIS_TLAST,
        M_AXIS_TVALID	=>  M_AXIS_TVALID
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

    clock_div : PROCESS(sys_clk_in, rst_n_in)
    BEGIN
        IF(rising_edge(sys_clk_in)) THEN
            sys_clk_div_in <= NOT sys_clk_div_in;
        END IF;    
    END PROCESS clock_div;


    reset_gen : PROCESS
    BEGIN
    WAIT FOR rand_time_val(C_CLK_PERIOD,C_CLK_PERIOD*3);
    rst_n_in <= '0';
    WAIT FOR rand_time_val(C_CLK_PERIOD*10,C_CLK_PERIOD*100);
    rst_n_in <= '1';
    WAIT;
    END PROCESS reset_gen;

    AXIS_M_DMA : PROCESS  --AXI stream master process DMA for sending data to PL
        VARIABLE i : natural := 0;
    BEGIN
        WAIT FOR rand_time_val(C_CLK_PERIOD*10,C_CLK_PERIOD*50);
        IF (halt = '0') THEN
            IF(s_is_reading = '0') THEN
                --initialize transfer
                i := 0;
                m_is_writing <= '1';
                WAIT FOR rand_time_val(C_CLK_PERIOD*5,C_CLK_PERIOD*10);
                WAIT UNTIL rising_edge(sys_clk_in);
                WAIT FOR 0 ns;
                S_AXIS_TVALID <= '1';
                WAIT FOR 0 ns;
                --S_AXIS_TDATA <= std_logic_vector(to_signed(integer(real(2**11-1)*sin(real(real(2*i)*freq_sig))), C_AXIS_DATA_WDT));
                S_AXIS_TDATA <= std_logic_vector(to_signed(integer(real(2**6-1)*real(i)), C_AXIS_DATA_WDT));
                i := i + 1;
                LOOP 
                    IF(rand_int(0,100) > C_PROB_DEASSERT) THEN  --random deassert
                        S_AXIS_TVALID <= '0';
                        WAIT FOR rand_time_val(C_CLK_PERIOD*5,C_CLK_PERIOD*10);
                    ELSE
                        S_AXIS_TVALID <= '1';
                        WAIT UNTIL rising_edge(sys_clk_in) AND S_AXIS_TREADY = '1'; --transfer accepted
                        WAIT FOR 0 ns;
                        S_AXIS_TDATA <= std_logic_vector(to_signed(integer(real(2**11-1)*sin(real(real(2*i)*freq_sig))), C_AXIS_DATA_WDT));
                        --S_AXIS_TDATA <= std_logic_vector(to_signed(integer(real(2**6-1)*real(i)), C_AXIS_DATA_WDT));
                        i := i + 1;
                        IF(i = C_FFT_SAMPLE_COUNT+1) THEN --last transfer 
                            i := 0; TODO: 
                            S_AXIS_TVALID <= '0';
                            EXIT;
                        END IF;
                    END IF;                     
                END LOOP;
                --wait for FFT payload to be processed and read
                m_is_writing <= '0';
                WAIT UNTIL rising_edge(s_is_reading);
                WAIT UNTIL falling_edge(s_is_reading);
                WAIT FOR rand_time_val(C_CLK_PERIOD*10,C_CLK_PERIOD*50);
                trans_cnt <= trans_cnt + 1;
            END IF;
        ELSE
            WAIT;
        END IF;
    END PROCESS AXIS_M_DMA;

    AXIS_S_DMA : PROCESS  --AXI stream slave process DMA for sending from PL to memory
        VARIABLE         i : natural := 0;
        VARIABLE real_part : real := 0.0;
        VARIABLE imag_part : real := 0.0;
    BEGIN
        WAIT FOR rand_time_val(C_CLK_PERIOD*10,C_CLK_PERIOD*50);
        IF (halt = '0') THEN
            IF(m_is_writing = '0') THEN
                WAIT UNTIL rising_edge(IRQ_FFT_DONE);
                WAIT FOR rand_time_val(C_CLK_PERIOD*10,C_CLK_PERIOD*50);
                --initialize transfer
                i := 0;
                s_is_reading <= '1';
                WAIT FOR rand_time_val(C_CLK_PERIOD*5,C_CLK_PERIOD*10);
                WAIT UNTIL rising_edge(sys_clk_in) AND M_AXIS_TVALID = '1';
                WAIT FOR 0 ns;
                M_AXIS_TREADY <= '1';
                WAIT FOR 0 ns;
                LOOP 
                    IF(rand_int(0,100) > C_PROB_DEASSERT) THEN  --random deassert
                        M_AXIS_TREADY <= '0';
                        WAIT FOR rand_time_val(C_CLK_PERIOD*5,C_CLK_PERIOD*10);
                    ELSE
                        M_AXIS_TREADY <= '1';
                        WAIT UNTIL rising_edge(sys_clk_in) AND M_AXIS_TVALID = '1'; --transfer accepted
                        WAIT FOR 0 ns;
                        --data_raw_arr(i)   <= M_AXIS_TDATA;
                        i := i + 1;
                        IF(M_AXIS_TLAST = '1') THEN
                            i := 0;
                            M_AXIS_TREADY <= '0';
                            EXIT;
                        END IF;
                    END IF;                     
                END LOOP;
                WAIT FOR rand_time_val(C_CLK_PERIOD*3,C_CLK_PERIOD*5);
                FOR k IN 0 TO C_FFT_SIZE-1 LOOP     --display amplitude of computed DFT                 
                    WAIT UNTIL rising_edge(sys_clk_in);
                    WAIT FOR 0 ns;
                    real_part := real(to_integer(signed(data_raw_arr(2*k))));
                    imag_part := real(to_integer(signed(data_raw_arr(2*k+1))));
                    data_amp_arr(k) <= sqrt(real_part*real_part + imag_part*imag_part);
                END LOOP;
                s_is_reading <= '0';
            END IF;
        ELSE
            WAIT;
        END IF;
    END PROCESS AXIS_S_DMA;

    starvation : PROCESS(trans_cnt)
        BEGIN
            IF trans_cnt = C_MAX_TRANS_CNT THEN
                halt <= '1';
            END IF;
    END PROCESS starvation; 


END behavioral;
