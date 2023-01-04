----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 06/13/2022 08:12:09 PM
-- Design Name: 
-- Module Name: spectral_analyzer_pl_wrapper - rtl
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: wrapper that translates AXI burst transaction to and from the FFT block 
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
USE IEEE.MATH_REAL.ALL;
LIBRARY xil_defaultlib;
USE xil_defaultlib.dig_top_pckg.ALL;


ENTITY spectral_analyzer_pl_wrapper IS
  PORT ( 
        -----------------------clocks and resets---------------------------------
           
        sys_clk_in         : IN  std_logic;
        rst_n_in           : IN  std_logic;
        
        -----------------------interrupts to PS----------------------------------
       
        IRQ_FFT_DONE       : OUT std_logic;
        
        -----------------------AXI stream memory to PL---------------------------
        
        S_AXIS_TREADY	: OUT std_logic;                                       --slave ready
        S_AXIS_TDATA	: IN std_logic_vector(C_AXIS_DATA_WDT-1 DOWNTO 0);     --data in
        S_AXIS_TSTRB	: IN std_logic_vector((C_AXIS_DATA_WDT/8)-1 DOWNTO 0); --byte qualifier, not used
        S_AXIS_TLAST	: IN std_logic;                                        --indicates boundary of last packet
        S_AXIS_TVALID	: IN std_logic;                                        --master initiate
        
        -----------------------AXI stream PL to memory---------------------------
        
        M_AXIS_TREADY	: IN  std_logic;                                        --slave ready
        M_AXIS_TDATA	: OUT std_logic_vector(C_AXIS_DATA_WDT-1 DOWNTO 0);     --data in
        M_AXIS_TSTRB	: OUT std_logic_vector((C_AXIS_DATA_WDT/8)-1 DOWNTO 0); --byte qualifier, not used
        M_AXIS_TLAST	: OUT std_logic;                                        --indicates boundary of last packet
        M_AXIS_TVALID	: OUT std_logic
  
  );
END spectral_analyzer_pl_wrapper;

ARCHITECTURE structural OF spectral_analyzer_pl_wrapper IS

    --FFT block signals
    SIGNAL data_re_0_in             :    std_logic_vector (C_SAMPLE_WDT-1 DOWNTO 0);
    SIGNAL data_im_0_in             :    std_logic_vector (C_SAMPLE_WDT-1 DOWNTO 0);
    SIGNAL data_re_1_in             :    std_logic_vector (C_SAMPLE_WDT-1 DOWNTO 0);
    SIGNAL data_im_1_in             :    std_logic_vector (C_SAMPLE_WDT-1 DOWNTO 0);
    SIGNAL data_re_0_out            :    std_logic_vector (C_SAMPLE_WDT-1 DOWNTO 0);
    SIGNAL data_im_0_out            :    std_logic_vector (C_SAMPLE_WDT-1 DOWNTO 0);
    SIGNAL data_re_1_out            :    std_logic_vector (C_SAMPLE_WDT-1 DOWNTO 0);
    SIGNAL data_im_1_out            :    std_logic_vector (C_SAMPLE_WDT-1 DOWNTO 0); 
    SIGNAL addr_0_in                :    std_logic_vector(C_FFT_SIZE_LOG2-1 DOWNTO 0);
    SIGNAL addr_1_in                :    std_logic_vector(C_FFT_SIZE_LOG2-1 DOWNTO 0);                            
    SIGNAL busy                     :    std_logic;   --fft processor is doing something
    SIGNAL request                  :    std_logic;   --request from external master, starts operation
    SIGNAL rx_ready                 :    std_logic;   --a sample is ready to be pushed into memory
    SIGNAL rx_val                   :    std_logic;   --a sample has been pushed into memory 
    SIGNAL rx_ack                   :    std_logic;   --end rx transaction of this sample and move onto another           :
    SIGNAL push                     :    std_logic;   --memory write signal for incoming sample, not used in burst mode
    SIGNAL rx_done                  :    std_logic;   --the memory is filled with external data, computation can begin
    SIGNAL comp_done                :    std_logic;   --algorithm has finished
    SIGNAL tx_ready                 :    std_logic;   --ready to transmit dft sample
    SIGNAL tx_val                   :    std_logic;   --the sample at the output is valid
    SIGNAL tx_ack                   :    std_logic;   --end tx transaction of this sample and move onto another
    SIGNAL pop                      :    std_logic;   --memory read acknowledge signal, not used in burst mode
    SIGNAL tx_done                  :    std_logic;   --all dft samples have been transmited
    SIGNAL all_done                 :    std_logic;    --everything is done
    SIGNAL overflow_warn            :    std_logic;   --somewhere in the computation, an addition overflow has ocurred, result may be unreliable (clipped)
    SIGNAL rx_single_ndouble_mode   :    std_logic;   -- = '1' - input samples are transmited one at a time through port 0
                                                       -- = '0' - input samples are transmited two at a time 
    SIGNAL tx_single_ndouble_mode   :    std_logic;   -- = '1' - output samples are transmited one at a time through port 0
                                                       -- = '0' - output samples are transmited two at a time
    SIGNAL burst_mode_en            :    std_logic;    --burst mode enable    
    SIGNAL s_fifo_out_data_q        :    std_logic_vector(C_SAMPLE_WDT-1 DOWNTO 0);          --FIFO output data
    SIGNAL addr_0_i_in              :    std_logic_vector(C_FFT_SIZE_LOG2-1 DOWNTO 0);
    SIGNAL data_re_window_d         :    std_logic_vector(C_SAMPLE_WDT-1 DOWNTO 0);
    SIGNAL m_write_cnt_std          :    std_logic_vector(C_FFT_SPECTR_COUNT_LOG2-1 DOWNTO 0);
    
    SIGNAL addr_window_fnc_q        :    std_logic_vector(C_FFT_SAMPLE_COUNT_LOG2-1 DOWNTO 0);
    SIGNAL window_read_en_q         :    std_logic;
    SIGNAL window_sample_d          :    std_logic_vector(C_SAMPLE_WDT-1 DOWNTO 0);	
    
    
    
    --AXI Slave - in charge of receiving samples from memory and pushing them into FFT    
            
    --FSM oversees writing samples data to FIFO and then outputting them to FFT block
    TYPE s_state IS ( IDLE,              --no action  
                      WRITE_FIFO,        --FIFO is being written to
                      ZERO_FILL,         --rest of FFT payload is being zero-filled
                      WAIT_FIFO_FULL     --FIFO is full, data needs to be popped
                  ); 
    
    --FSM oversees writing samples data to FIFO from FFT block and then outputting them memory
    TYPE m_state IS ( IDLE,              --no action  
                      WRITE_FIFO,        --FIFO is being written to
                      WAIT_FIFO_FULL     --FIFO is full, data needs to be popped
                  ); 
                                 
    SIGNAL s_axis_tready_i	: std_logic;
    -- State variable
    SIGNAL  s_exec_state   : s_state; 
    SIGNAL  s_exec_state_i : s_state;  
    -- FIFO implementation SIGNALs
    SIGNAL  byte_index : natural;    
    -- FIFO write enable
    SIGNAL s_fifo_wren : std_logic;
    SIGNAL s_fifo_rden : std_logic;
    -- FIFO full flag
    SIGNAL s_fifo_full_flag : std_logic;
    -- FIFO write pointer
    SIGNAL s_write_cnt  : natural RANGE 0 TO C_FFT_SAMPLE_COUNT-1;
    SIGNAL s_read_cnt   : natural RANGE 0 TO C_FFT_SIZE-1;
    SIGNAL s_read_cnt_i : natural RANGE 0 TO C_FFT_SIZE-1;
    SIGNAL s_write_pointer : natural RANGE 0 TO C_FIFO_ADDR_SIZE-1;
    SIGNAL s_read_pointer  : natural RANGE 0 TO C_FIFO_ADDR_SIZE-1;
    -- sink has accepted all the streaming data and stored IN FIFO
    SIGNAL s_writes_done : std_logic;
    SIGNAL s_reads_done  : std_logic;
    SIGNAL s_all_done    : std_logic; --zero-filling has been completed, FFT can start computing

    TYPE FIFO_TYPE IS ARRAY (0 TO (C_FIFO_WORD_SIZE-1)) OF std_logic_vector(C_SAMPLE_WDT-1 DOWNTO 0);
    SIGNAL s_stream_data_fifo : FIFO_TYPE;
    SIGNAL m_stream_data_fifo : FIFO_TYPE;

    --AXI Master - in charge of pushing FFT outputs into FIFO and then streaming them to memory
    
    -- State variable                                                                 
    SIGNAL m_exec_state : m_state;     
                                                  
    SIGNAL m_write_cnt      : natural RANGE 0 TO C_FFT_SPECTR_COUNT-1;
    SIGNAL m_read_cnt       : natural RANGE 0 TO C_FFT_SPECTR_COUNT-1;
    SIGNAL m_write_cnt_i    : natural RANGE 0 TO C_FFT_SPECTR_COUNT-1;
    SIGNAL m_write_pointer  : natural RANGE 0 TO C_FIFO_ADDR_SIZE-1;
    SIGNAL m_read_pointer   : natural RANGE 0 TO C_FIFO_ADDR_SIZE-1; 
    
    SIGNAL m_writes_done : std_logic;
    SIGNAL m_reads_done  : std_logic; 

    
    --streaming data valid
    SIGNAL m_axis_tvalid_d	    : std_logic;
    --streaming data valid delayed by one clock cycle
    SIGNAL m_axis_tvalid_q	    : std_logic;
    --Last OF the streaming data 
    SIGNAL m_axis_tlast_d	    : std_logic;
    --Last OF the streaming data delayed by one clock cycle
    SIGNAL m_axis_tlast_q	    : std_logic;
    --FIFO implementation signals
    SIGNAL m_stream_data_out	: std_logic_vector(C_AXIS_DATA_WDT-1 DOWNTO 0);
        -- FIFO write enable
    SIGNAL m_fifo_wren   : std_logic;
    SIGNAL m_fifo_wren_i : std_logic;
    SIGNAL m_fifo_rden   : std_logic;
    -- FIFO full flag
    SIGNAL m_fifo_full_flag            : std_logic; 
    SIGNAL m_data_out_isimag_nreal     : std_logic;

    --signals for observation in GL
    SIGNAL s_fifo_out_data_q_o : std_logic_vector(C_SAMPLE_WDT-1 DOWNTO 0);
    SIGNAL window_sample_d_o   : std_logic_vector(C_SAMPLE_WDT-1 DOWNTO 0);
    ATTRIBUTE S: string;
    ATTRIBUTE S OF s_fifo_out_data_q_o : SIGNAL IS "TRUE";
    ATTRIBUTE S OF window_sample_d_o   : SIGNAL IS "TRUE";
    
                                                                                                                           

    COMPONENT fft_dig_top IS
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
           burst_mode_en            : IN  std_logic    --burst mode enable                                                                                                                       
           
           );
    END COMPONENT fft_dig_top;
    
    COMPONENT fft_window_fnc_LUT IS
    PORT (
           sys_clk_in        : IN  std_logic;
           addr_window_fnc_q : IN  std_logic_vector(C_FFT_SAMPLE_COUNT_LOG2-1 DOWNTO 0);
           window_read_en_q  : IN  std_logic;
           window_sample_d   : OUT std_logic_vector(C_SAMPLE_WDT-1 DOWNTO 0)
    );
    END COMPONENT fft_window_fnc_LUT;
    
    
BEGIN

    fft_block : fft_dig_top
        PORT MAP( 
          
           sys_clk_in              => sys_clk_in, 
           rst_n_in                => rst_n_in, 
           data_re_0_in            => data_re_0_in, 
           data_im_0_in            => data_im_0_in, 
           data_re_1_in            => data_re_1_in, 
           data_im_1_in            => data_im_1_in, 
           data_re_0_out           => data_re_0_out, 
           data_im_0_out           => data_im_0_out, 
           data_re_1_out           => data_re_1_out, 
           data_im_1_out           => data_im_1_out,   
           addr_0_in               => addr_0_in, 
           addr_1_in               => addr_1_in,    
           busy                    => busy, 
           request                 => request, 
           rx_ready                => rx_ready, 
           rx_val                  => rx_val, 
           rx_ack                  => rx_ack, 
           push                    => push, 
           rx_done                 => rx_done, 
           comp_done               => comp_done, 
           tx_ready                => tx_ready, 
           tx_val                  => tx_val, 
           tx_ack                  => tx_ack, 
           pop                     => pop, 
           tx_done                 => tx_done, 
           all_done                => all_done,   
           overflow_warn           => overflow_warn,  
           rx_single_ndouble_mode  => rx_single_ndouble_mode,                                  
           tx_single_ndouble_mode  => tx_single_ndouble_mode,                                   
           burst_mode_en           => burst_mode_en            
           
           );
    fft_window : fft_window_fnc_LUT
    PORT MAP(
           sys_clk_in        => sys_clk_in,
           addr_window_fnc_q => addr_window_fnc_q,
           window_read_en_q  => window_read_en_q,
           window_sample_d   => window_sample_d  
    );
           
    --------------------------------------------------------------------------
    --------------AXI Slave---------------------------------------------------
    --------------------------------------------------------------------------
    
           
    S_AXIS_TREADY	<= s_axis_tready_i;
    
    axi_slave_fsm : PROCESS(sys_clk_in, rst_n_in)
    BEGIN
      IF(rst_n_in = '0') THEN
          s_exec_state <= IDLE;
      ELSIF (rising_edge (sys_clk_in)) THEN
          CASE (s_exec_state) IS
            WHEN IDLE     => 
              IF (S_AXIS_TVALID = '1') THEN    --tvalid is asserted => start accepting data
                s_exec_state <= WRITE_FIFO; 
              ELSE
                s_exec_state <= IDLE;
              END IF;  
            WHEN WRITE_FIFO => 
              IF (s_writes_done = '1' AND s_reads_done = '1') THEN  --all writes and reads are done
                s_exec_state <= ZERO_FILL;  
              ELSE
                IF (s_fifo_full_flag = '1') THEN --FIFO is full, wait for some reads so that space for new writes is cleared
                   s_exec_state <= WAIT_FIFO_FULL;
                ELSE
                   s_exec_state <= WRITE_FIFO; 
                END IF;
              END IF; 
            WHEN ZERO_FILL                     =>
              IF(s_all_done = '1') THEN
                s_exec_state <= IDLE;
              ELSE
                s_exec_state <= ZERO_FILL;
              END IF;    
            WHEN WAIT_FIFO_FULL                =>
              IF (s_fifo_full_flag = '1') THEN --FIFO is full, wait for some reads so that space for new writes is cleared
                s_exec_state <= WAIT_FIFO_FULL;
              ELSE
                s_exec_state <= WRITE_FIFO; 
              END IF;
            WHEN OTHERS    => 
              s_exec_state <= IDLE;
          END CASE;
      END IF;  

    END PROCESS axi_slave_fsm;

    s_axis_tready_i <= '1' WHEN ((s_exec_state = WRITE_FIFO) AND (s_writes_done = '0')) ELSE '0';

    --caching of write count (FFT addr) 
    --to match the latency of FFT writes and master buffer reads 
    s_buffer_cache : PROCESS(sys_clk_in, rst_n_in) 
    BEGIN  
      IF(rst_n_in = '0') THEN   
          s_read_cnt_i   <= 0; 
          s_exec_state_i <= IDLE;                                                                                  
      ELSIF (rising_edge(sys_clk_in)) THEN                                                          
          s_read_cnt_i   <= s_read_cnt;  
          s_exec_state_i <= s_exec_state;
      END IF;                                                                                                                                                           
    END PROCESS s_buffer_cache;

    s_cnt_to_ptr : PROCESS(s_write_cnt,s_read_cnt) --use lower order bits of write and read counters as pointers to circular buffer FIFO
        VARIABLE wr_cnt_lower_order_bits : std_logic_vector(C_FFT_SAMPLE_COUNT_LOG2-1 DOWNTO 0);
        VARIABLE rd_cnt_lower_order_bits : std_logic_vector(C_FFT_SIZE_LOG2-1 DOWNTO 0);
    BEGIN
        wr_cnt_lower_order_bits := std_logic_vector(to_unsigned(s_write_cnt,C_FFT_SAMPLE_COUNT_LOG2));
        rd_cnt_lower_order_bits := std_logic_vector(to_unsigned(s_read_cnt,C_FFT_SIZE_LOG2));
        s_write_pointer <= to_integer(unsigned(wr_cnt_lower_order_bits(C_FIFO_ADDR_SIZE-1 DOWNTO 0)));
        s_read_pointer  <= to_integer(unsigned(rd_cnt_lower_order_bits(C_FIFO_ADDR_SIZE-1 DOWNTO 0)));
    END PROCESS s_cnt_to_ptr;
    

    s_fifo_control : PROCESS(sys_clk_in, rst_n_in)
    BEGIN
      IF(rst_n_in = '0') THEN
          s_write_cnt     <= 0;
          s_read_cnt      <= 0;
          s_writes_done   <= '0';
          s_reads_done    <= '0';
          s_all_done      <= '0';
      ELSIF (rising_edge (sys_clk_in)) THEN  
          IF(s_exec_state = IDLE) THEN --reset on idle
              s_write_cnt     <= 0;
              s_read_cnt      <= 0;
              s_writes_done   <= '0';
              s_reads_done    <= '0';
              s_all_done      <= '0';
          ELSE
              IF (s_write_cnt < C_FFT_SAMPLE_COUNT-1) THEN
                IF (s_fifo_wren = '1') THEN
                  --write pointer is incremented after each write
                  s_write_cnt   <= s_write_cnt + 1;
                  s_writes_done <= '0';
                END IF;
              ELSE
                  s_writes_done <= '1';
              END IF;
              
              IF (s_read_cnt < C_FFT_SAMPLE_COUNT-1) THEN  --reading ADC samples
                  IF (s_fifo_rden = '1' AND rx_ready = '1') THEN
                      --read pointer is incremented after each read
                      s_read_cnt   <= s_read_cnt + 1;
                      s_reads_done <= '0';
                  END IF;
              ELSIF(s_read_cnt = C_FFT_SAMPLE_COUNT-1) THEN
                s_reads_done <= '1';
                s_read_cnt   <= s_read_cnt + 1; 
              ELSE  --zero-filling
                IF(rx_ready = '1') THEN
                  s_read_cnt   <= s_read_cnt + 1; 
                  s_all_done   <= '0';
                END IF;
                IF(s_read_cnt = C_FFT_SIZE-1) THEN 
                  s_all_done   <= '1';  
                END IF;
              END IF;      
            END IF;
        END IF;
    END PROCESS s_fifo_control;
    
    ---------------------------------------------
    --FFT write signals generation--------------
    ---------------------------------------------
    
    rx_single_ndouble_mode <= '1';
    tx_single_ndouble_mode <= '1';
    burst_mode_en          <= '1';
    window_read_en_q       <= s_fifo_rden;
    addr_window_fnc_q      <= std_logic_vector(to_unsigned(s_read_cnt,C_FFT_SAMPLE_COUNT_LOG2));
    addr_1_in              <= (OTHERS => '0');
    data_re_1_in           <= (OTHERS => '0');
    data_im_1_in           <= (OTHERS => '0');
    
    request     <= '1' WHEN (s_exec_state /= IDLE) OR (m_exec_state /= IDLE) ELSE '0';
    rx_done     <= s_all_done;
    tx_done     <= m_writes_done AND m_reads_done;
       
    ---------------------------------------------
    --FIFO read/write enable generation----------
    ---------------------------------------------
        
    --write to FIFO when tvalid and tready are asserted
    s_fifo_wren <= S_AXIS_TVALID AND s_axis_tready_i;
    --read from FIFO when we are not idling and never read and write from/to the same address
    s_fifo_rden <= '1' WHEN  (s_exec_state /= IDLE) AND (integer(s_write_cnt) - integer(s_read_cnt) > 0) ELSE '0'; 
    --FIFO is full when the read and write counters distance is as large as the FIFO size
    s_fifo_full_flag <= '1' WHEN ((integer(s_write_cnt) - integer(s_read_cnt)) >= C_FIFO_WORD_SIZE-1) ELSE '0';

    -- FIFO Implementation (circular buffer)
     --streaming input data is stored in circular buffer
    s_fifo_circ_buff : PROCESS(sys_clk_in)
    BEGIN
      IF (rising_edge (sys_clk_in)) THEN
        IF (s_fifo_wren = '1') THEN
          s_stream_data_fifo(s_write_pointer) <= S_AXIS_TDATA(C_SAMPLE_WDT-1 DOWNTO 0);
          IF(C_VERB = VERB_HIGH) THEN
            REPORT "Value: " & integer'image(to_integer(signed(S_AXIS_TDATA))) & 
            "@ global addr: [" & integer'image(s_write_cnt) & 
            "] @ circ buffer addr: [" &  integer'image(s_write_pointer) &
            "] written to the slave circ buffer";
          END IF;
        END IF;
        
        IF (s_fifo_rden = '1') THEN
          s_fifo_out_data_q <= s_stream_data_fifo(s_read_pointer);
          IF(C_VERB = VERB_HIGH) THEN
            REPORT "Value: " & integer'image(to_integer(signed(s_stream_data_fifo(s_read_pointer)))) & 
            "@ global addr: [" & integer'image(s_read_cnt) & 
            "] @ circ buffer addr: [" &  integer'image(s_read_pointer) &
            "] read from the slave circ buffer";
          END IF;
        END IF;
      END  IF;
    END PROCESS s_fifo_circ_buff;

    --circular buffer assertions
    ASSERT (integer(s_write_cnt) - integer(s_read_cnt)) <= C_FIFO_WORD_SIZE OR s_exec_state = ZERO_FILL 
    REPORT "Not yet read FIFO data has been overwritten!"
    SEVERITY ERROR;
    
    ASSERT (integer(s_write_cnt) - integer(s_read_cnt)) >= 0 OR (s_exec_state = IDLE OR s_exec_state = ZERO_FILL) OR s_writes_done = '1'
    REPORT "Read pointer cannot be larger than write pointer, we cannot read data that has not yet been written!"
    SEVERITY ERROR; 
    
    --synthesis translate_off
    s_asrt_proc_rdwr_same_addr : PROCESS(sys_clk_in)
    BEGIN
      IF(rising_edge(sys_clk_in)) THEN
        ASSERT NOT ((s_write_cnt = s_read_cnt) AND s_fifo_rden = '1' AND s_fifo_wren = '1')
        REPORT "Cannot write and read from the same FIFO address!"
        SEVERITY ERROR; 
      END IF;
    END PROCESS s_asrt_proc_rdwr_same_addr;  
    --synthesis translate_on
    
    ASSERT NOT(s_reads_done = '1' AND s_writes_done = '0')
    REPORT "Reads cannot be done before writes!"
    SEVERITY ERROR;  
    
    window_mult : PROCESS(s_fifo_out_data_q, window_sample_d) --AXI samples windowing
        VARIABLE data_mult : signed(2*C_SAMPLE_WDT-1 DOWNTO 0);
    BEGIN
        data_mult := signed(s_fifo_out_data_q)*signed(window_sample_d); 
        data_re_window_d <= std_logic_vector(shift_right(data_mult,C_WIND_FNC_SCALE_LOG2)(C_SAMPLE_WDT-1 DOWNTO 0));
    END PROCESS window_mult;
    
  
  data_addr_in_reg : PROCESS(s_exec_state, m_exec_state, s_read_cnt_i, m_write_cnt, data_re_window_d)     --mux for inputting data & address to the FFT block
  BEGIN
    IF(s_exec_state /= IDLE AND m_exec_state = IDLE) THEN   --we are receiving data from memory
      addr_0_in    <= std_logic_vector(to_unsigned(s_read_cnt_i,C_FFT_SIZE_LOG2));
      IF(s_exec_state = WRITE_FIFO OR s_exec_state = WAIT_FIFO_FULL) THEN --first fill fft payload with memory samples, rest is zero-filled
       data_re_0_in <= data_re_window_d;
      ELSE
       data_re_0_in <= (OTHERS => '0');         
      END IF;              
      data_im_0_in <= (OTHERS => '0'); 
    ELSIF(s_exec_state = IDLE AND m_exec_state /= IDLE) THEN --we are streaming data to memory 
      --for every two writes into FIFO we need one read of FFT (we read imag and real parts simultaneously)
      addr_0_in    <= std_logic_vector(to_unsigned(m_write_cnt,C_FFT_SPECTR_COUNT_LOG2)(C_FFT_SPECTR_COUNT_LOG2-1 DOWNTO 1)); 
      data_re_0_in <= (OTHERS => '0');              
      data_im_0_in <= (OTHERS => '0');
    ELSE
      addr_0_in    <= (OTHERS => '0'); 
      data_re_0_in <= (OTHERS => '0');
      data_im_0_in <= (OTHERS => '0');
    END IF;
  END PROCESS data_addr_in_reg;
    
    
    --------------------------------------------------------------------------
    --------------AXI Master--------------------------------------------------
    --------------------------------------------------------------------------
    
    -- I/O Connections assignments

    M_AXIS_TVALID	<= m_axis_tvalid_q;
    M_AXIS_TDATA	<= m_stream_data_out;
    M_AXIS_TLAST	<= m_axis_tlast_q;
    M_AXIS_TSTRB	<= (OTHERS => '1');


    -- Control state machine implementation                                               
    axi_master_fsm : PROCESS(sys_clk_in, rst_n_in)                                                                        
    BEGIN 
      IF(rst_n_in = '0') THEN
          m_exec_state <= IDLE;                                                                                      
      ELSIF(rising_edge(sys_clk_in)) THEN                                                                                                                                  
          CASE (m_exec_state) IS                                                              
            WHEN IDLE     =>                                                                    
                IF(comp_done = '1') THEN                                     
                   m_exec_state <= WRITE_FIFO;   --FFT data are ready, start filling up the FIFO
                ELSE
                   m_exec_state <= IDLE;
                END IF;                                                                                                                                                                                                          
            WHEN WRITE_FIFO => 
                IF (m_writes_done = '1' AND m_reads_done = '1') THEN  --all writes and reads are done
                  m_exec_state <= IDLE;  
                ELSE
                  IF (m_fifo_full_flag = '1') THEN --FIFO is full, wait for some reads so that space for new writes is cleared
                     m_exec_state <= WAIT_FIFO_FULL;
                  ELSE
                     m_exec_state <= WRITE_FIFO; 
                  END IF;
                END IF;
            WHEN WAIT_FIFO_FULL                =>
               IF (m_fifo_full_flag = '1') THEN --FIFO is full, wait for some reads so that space for new writes is cleared
                   m_exec_state <= WAIT_FIFO_FULL;
                ELSE
                   m_exec_state <= WRITE_FIFO; 
                END IF;                                                                        
            WHEN OTHERS    =>                                                                   
              m_exec_state <= IDLE;                                                                                                                                                      
          END CASE;                                                                                                                                                          
      END IF;                                                                                   
    END PROCESS axi_master_fsm;                                                                                


    --tvalid generation
    m_axis_tvalid_d <= '1' WHEN ((m_exec_state /= IDLE) AND (m_read_cnt <= C_FFT_SPECTR_COUNT-1) AND (m_read_cnt > 0)) ELSE '0';                                                                                              
    -- AXI tlast generation                                                                                                                                 
    m_axis_tlast_d <= '1' WHEN (m_read_cnt = C_FFT_SPECTR_COUNT-1) ELSE '0';
    
    --IRQ on FFT done generation
    IRQ_FFT_DONE <= tx_ready; 

    --caching of write count (buffer addr) and buffer wr_en 
    --to match the latency of FFT reads and master buffer writes
    m_buffer_cache : PROCESS(sys_clk_in, rst_n_in) 
    BEGIN  
      IF(rst_n_in = '0') THEN   
          m_write_cnt_i <= 0;                                                                                    
          m_fifo_wren_i <= '0';
      ELSIF (rising_edge(sys_clk_in)) THEN                                                          
          m_write_cnt_i <= m_write_cnt;                                                         
          m_fifo_wren_i <= m_fifo_wren;
      END IF;                                                                                                                                                           
    END PROCESS m_buffer_cache; 

    m_cnt_to_ptr : PROCESS(m_write_cnt_i,m_read_cnt) --use lower order bits of write and read counters as pointers to circular buffer FIFO
        VARIABLE wr_cnt_lower_order_bits : std_logic_vector(C_FFT_SPECTR_COUNT_LOG2-1 DOWNTO 0);
        VARIABLE rd_cnt_lower_order_bits : std_logic_vector(C_FFT_SPECTR_COUNT_LOG2-1 DOWNTO 0);
    BEGIN
        wr_cnt_lower_order_bits := std_logic_vector(to_unsigned(m_write_cnt_i,C_FFT_SPECTR_COUNT_LOG2));
        rd_cnt_lower_order_bits := std_logic_vector(to_unsigned(m_read_cnt,C_FFT_SPECTR_COUNT_LOG2));
        m_write_pointer <= to_integer(unsigned(wr_cnt_lower_order_bits(C_FIFO_ADDR_SIZE-1 DOWNTO 0)));
        m_read_pointer  <= to_integer(unsigned(rd_cnt_lower_order_bits(C_FIFO_ADDR_SIZE-1 DOWNTO 0)));
    END PROCESS m_cnt_to_ptr;                   
                        
    tlast_tvalid_cache : PROCESS(sys_clk_in, rst_n_in)   --caching of tlast and tvalid to match data latency                                                                            
    BEGIN  
      IF(rst_n_in = '0') THEN   
          m_axis_tvalid_q <= '0';                                                                
          m_axis_tlast_q <= '0';                                                                                      
      ELSIF (rising_edge(sys_clk_in)) THEN                                                                                                                                    
          m_axis_tvalid_q <= m_axis_tvalid_d;                                                        
          m_axis_tlast_q <= m_axis_tlast_d;                                                          
      END IF;                                                                                                                                                           
    END PROCESS tlast_tvalid_cache;                                                                                   

    m_fifo_control : PROCESS(sys_clk_in, rst_n_in)
    BEGIN
      IF(rst_n_in = '0') THEN
           m_read_cnt    <=  0;
           m_reads_done  <= '0';
           m_write_cnt   <=  0;
           m_writes_done <= '0';
      ELSIF (rising_edge(sys_clk_in)) THEN
        IF(m_exec_state = IDLE) THEN
          m_read_cnt    <=  0;
          m_reads_done  <= '0';
          m_write_cnt   <=  0;
          m_writes_done <= '0';
        ELSE
          IF (m_read_cnt < C_FFT_SPECTR_COUNT-1) THEN
            IF (m_fifo_rden = '1') THEN
              --read pointer is incremented after each read
              m_read_cnt   <= m_read_cnt + 1;
              m_reads_done <= '0';
            END IF;
          ELSE
            m_reads_done <= '1';
          END IF;
                    
          IF (m_write_cnt < C_FFT_SPECTR_COUNT-1) THEN
              IF (m_fifo_wren = '1' AND tx_ready = '1') THEN
                  --write pointer is incremented after each write
                  m_write_cnt   <= m_write_cnt + 1;
                  m_writes_done <= '0';
              END IF;
          ELSE
            m_writes_done <= '1';
          END IF; 
        END IF;   
      END IF;
    END PROCESS m_fifo_control;                                                                   

    --read from FIFO when slave is ready and data is valid and there is data ready in FIFO
    m_fifo_rden <= '1' WHEN ((M_AXIS_TREADY = '1') AND (m_axis_tvalid_q = '1') AND ((integer(m_write_cnt_i) - integer(m_read_cnt)) > 0)) OR (m_write_cnt_i = 1) ELSE '0';  
    --write to FIFO when we are not idling or at full FIFO capacity
    m_fifo_wren <= '1' WHEN (m_exec_state = WRITE_FIFO) AND (m_writes_done = '0') ELSE '0'; 
    --FIFO is full when the read and write counters distance is as large as the FIFO size
    m_fifo_full_flag <= '1' WHEN (integer(m_write_cnt) - integer(m_read_cnt)) >= C_FIFO_WORD_SIZE-1 ELSE '0';  
    
    m_write_cnt_std <= std_logic_vector(to_unsigned(m_write_cnt_i,C_FFT_SPECTR_COUNT_LOG2));                              
    m_data_out_isimag_nreal <= '0' WHEN  m_write_cnt_std(0) = '0' ELSE '1';                                                                                       
                                                                                    
    -- FIFO Implementation (circular buffer)
    --streaming input data is stored in circular buffer, real part of FFT is stored on even addresses, imag part on odd addresses
    m_fifo_circ_buff : PROCESS(sys_clk_in)
     -- VARIABLE real_part : std_logic_vector(C_AXIS_DATA_WDT-1 DOWNTO 0); TODO: remove if proven redundant
     -- VARIABLE imag_part : std_logic_vector(C_AXIS_DATA_WDT-1 DOWNTO 0);
    BEGIN
      IF (rising_edge(sys_clk_in)) THEN
        IF (m_fifo_rden = '1') THEN
          m_stream_data_out <= std_logic_vector(to_signed(to_integer(signed(m_stream_data_fifo(m_read_pointer))),C_AXIS_DATA_WDT)); --sign extension
          IF(C_VERB = VERB_HIGH) THEN
            REPORT "Value: " & integer'image(to_integer(signed(m_stream_data_fifo(m_read_pointer)))) & 
            "@ global addr: [" & integer'image(m_read_cnt) & 
            "] @ circ buffer addr: [" &  integer'image(m_read_pointer) &
            "] read from the master circ buffer";
          END IF;
        END IF;
        
        IF (m_fifo_wren_i = '1') THEN
          IF(m_data_out_isimag_nreal = '0') THEN
              --real_part := std_logic_vector(to_signed(to_integer(signed(data_re_0_out)),C_AXIS_DATA_WDT));  --sign extension
              m_stream_data_fifo(m_write_pointer) <= data_re_0_out;  
              IF(C_VERB = VERB_HIGH) THEN
                REPORT "Value (real): " & integer'image(to_integer(signed(data_re_0_out))) & 
                "@ global addr: [" & integer'image(m_write_cnt_i) & 
                "] @ circ buffer addr: [" &  integer'image(m_write_pointer) &
                "] written to the master circ buffer";
              END IF;
          ELSE    
              --imag_part := std_logic_vector(to_signed(to_integer(signed(data_im_0_out)),C_AXIS_DATA_WDT));  --sign extension
              m_stream_data_fifo(m_write_pointer) <= data_im_0_out;  
              IF(C_VERB = VERB_HIGH) THEN
                REPORT "Value (imag): " & integer'image(to_integer(signed(data_im_0_out))) & 
                "@ global addr: [" & integer'image(m_write_cnt_i) & 
                "] @ circ buffer addr: [" &  integer'image(m_write_pointer) &
                "] written to the master circ buffer";
              END IF;
          END IF;
        END IF;
      END  IF;
    END PROCESS m_fifo_circ_buff;

    --circular buffer assertions
    ASSERT (integer(m_write_cnt_i) - integer(m_read_cnt)) <= C_FIFO_WORD_SIZE OR m_exec_state = IDLE
    REPORT "Not yet read FIFO data has been overwritten!"
    SEVERITY ERROR;
    
    ASSERT (integer(m_write_cnt_i) - integer(m_read_cnt)) >= 0 OR (m_exec_state = IDLE)
    REPORT "Read pointer cannot be larger than write pointer, we cannot read data that has not yet been written!"
    SEVERITY ERROR; 

    --synthesis translate_off
    m_asrt_proc_rdwr_same_addr : PROCESS(sys_clk_in)
    BEGIN
      IF(rising_edge(sys_clk_in)) THEN
        ASSERT NOT ((m_write_cnt_i = m_read_cnt) AND m_fifo_rden = '1' AND m_fifo_wren_i = '1')
        REPORT "Cannot write and read from the same FIFO address!"
        SEVERITY ERROR; 
      END IF;
    END PROCESS m_asrt_proc_rdwr_same_addr;  
    --synthesis translate_on
    
    ASSERT NOT(m_reads_done = '1' AND m_writes_done = '0')
    REPORT "Reads cannot be done before writes!"
    SEVERITY ERROR;

  ASSERT C_FFT_SAMPLE_COUNT >= C_FIFO_WORD_SIZE
  REPORT "No point in having a FIFO larger than a single payload, aborting simulation!"
  SEVERITY FAILURE;

  ASSERT C_FFT_SAMPLE_COUNT <= C_FFT_SIZE
  REPORT "Number of samples can not be larger than the FFT sample size, aborting simulation!"
  SEVERITY FAILURE;
    

END structural;
