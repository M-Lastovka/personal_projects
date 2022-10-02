%% script to generate a windowing function ROM for FPGA implementation

sample_count = 2^2;
sample_wdt = 24;
scale_const_log2 = sample_wdt-1; %determines how many bits to the left do we shift the twiddle factors
block_wdt = 4;         %number of twiddle factors per line

if log2(sample_count) ~= round(log2(sample_count))
    printf("Invalid N of samples, must be power of 2\n"); 
end
    
if mod(32,2) ~= 0
    printf("Sample size must be even\n");
end
    
if scale_const_log2 > sample_wdt
    printf("Invalid scale_const_log2 value\n");
end

    
%%generate twiddle factor LUT
    
    fileID = fopen(strcat('fft_window_fnc_LUT',string(log2(sample_count)),'_',string(sample_wdt),'b.vhd'), 'w');

    %function definition
    temp = '';
    temp = strcat(temp, '----------------------------------------------------------------------------------\n');
    temp = strcat(temp, '-- Create Date: 08/17/2021 05:27:38 PM:\n');
    temp = strcat(temp, '-- Module Name: fft_window_fnc_LUT - rtl\n');
    temp = strcat(temp, '-- Description: LUT samples of hann window, half of window is stored (input address has to symmetrized)\n');
    temp = strcat(temp, '-- Dependencies: dig_top_pckg \n');
    temp = strcat(temp, '-- Additional Comments: This code is auto-generated, do NOT edit manually! \n');
    temp = strcat(temp, '----------------------------------------------------------------------------------\n\n\n');
    
    temp = strcat(temp, 'LIBRARY IEEE;\n');
    temp = strcat(temp, 'USE IEEE.STD_LOGIC_1164.ALL;\n');
    temp = strcat(temp, 'use IEEE.NUMERIC_STD.ALL;\n');
    temp = strcat(temp, 'LIBRARY xil_defaultlib;\n');
    temp = strcat(temp, 'USE xil_defaultlib.dig_top_pckg.ALL;\n\n\n');
    
    temp = strcat(temp, 'ENTITY fft_window_fnc_LUT IS\n');
    temp = strcat(temp, '    PORT (\n');
    temp = strcat(temp, '           sys_clk_in            : IN  std_logic;\n');
    temp = strcat(temp, '           addr_window_fnc_q     : IN  std_logic_vector(C_FFT_SAMPLE_COUNT_LOG2-1 DOWNTO 0);\n');
    temp = strcat(temp, '           window_read_en_q      : IN  std_logic;\n');
    temp = strcat(temp, '           window_sample_d       : OUT std_logic_vector(C_SAMPLE_WDT-1 DOWNTO 0)\n');
    temp = strcat(temp, '           );\n');
    temp = strcat(temp, 'END fft_window_fnc_LUT;\n\n\n');
    
    temp = strcat(temp, 'ARCHITECTURE rtl OF fft_window_fnc_LUT IS\n\n');
    temp = strcat(temp, 'SIGNAL addr_window_fnc_symm_q : std_logic_vector(C_FFT_SAMPLE_COUNT_LOG2-2 DOWNTO 0);\n');
    temp = strcat(temp, 'TYPE lut_mem_space IS ARRAY (0 TO 2**(C_FFT_SAMPLE_COUNT_LOG2-1)-1) OF std_logic_vector(C_SAMPLE_WDT-1 DOWNTO 0);\n');
    temp = strcat(temp, 'CONSTANT C_WINDOW_FNC_LUT : lut_mem_space := (\n  ');
    
    fprintf(fileID, temp);
    temp = '';
    
    break_index = 0;
    temp_re = 0;
    temp_re_bin = 0;
    padding_str = '0';
    window_samples = hann(sample_count);
    
    for index = 1:sample_count/2 
        break_index = break_index + 1;
        
        temp_re = window_samples(index)*2^(scale_const_log2);        

        temp_re_bin = dec2bin(floor(temp_re));
        %temp_re_bin = strcat('0',temp_re_bin);
        padding_str = '0';
        
        %sign extension
        temp_re_bin = strcat(repmat(padding_str,1,sample_wdt - length(temp_re_bin)), temp_re_bin);
        
        if index == sample_count/2
            fprintf(fileID, strcat('"',temp_re_bin,'" '));
        else
            fprintf(fileID, strcat('"',temp_re_bin,'", '));
        end
        
        if  break_index == block_wdt
            fprintf(fileID,'\n');   %so that it looks more block-like
            break_index = 0;
        end
    end
    
    temp = strcat(temp, ');\n');
    temp = strcat(temp, 'BEGIN\n\n');
    temp = strcat(temp, 'addr_symm : PROCESS(addr_window_fnc_q)\n');
    temp = strcat(temp, 'BEGIN\n');
    temp = strcat(temp, 'IF(addr_window_fnc_q(C_FFT_SAMPLE_COUNT_LOG2-1) = ''0'') THEN\n');
    temp = strcat(temp, '    addr_window_fnc_symm_q <= addr_window_fnc_q(C_FFT_SAMPLE_COUNT_LOG2-2 DOWNTO 0);\n');
    temp = strcat(temp, 'ELSE\n');
    temp = strcat(temp, '    addr_window_fnc_symm_q <= NOT (addr_window_fnc_q(C_FFT_SAMPLE_COUNT_LOG2-2 DOWNTO 0));\n');
    temp = strcat(temp, 'END IF;\n');
    temp = strcat(temp, 'END PROCESS addr_symm;\n\n');
    temp = strcat(temp, 'LUT_proc : PROCESS(sys_clk_in)\n');
    temp = strcat(temp, 'BEGIN\n');
    temp = strcat(temp, 'IF (rising_edge(sys_clk_in)) THEN\n');
    temp = strcat(temp,'  IF (window_read_en_q = ''1'') THEN\n');
    temp = strcat(temp,'    window_sample_d <= C_WINDOW_FNC_LUT(to_integer(unsigned(addr_window_fnc_symm_q)));\n');
    temp = strcat(temp,'  END IF;\n');
    temp = strcat(temp,'END IF;\n');
    temp = strcat(temp, 'END PROCESS LUT_proc;\n\n');
    temp = strcat(temp, 'END rtl;\n');
    
    fprintf(fileID, temp);
    fclose(fileID);
    
    