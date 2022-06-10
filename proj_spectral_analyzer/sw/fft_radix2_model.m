%author: Martin Lastovka, contact at lastoma4@fel.cvut.cz

%implementation of FFT Radix 2, decimation in time

%constants declaration & initialization

size_of_fft = 2^4;
lwr_cut_off = 7;

N_of_bins = 18;
bin_edges = ceil((2).^((1:N_of_bins-1)*(log2(size_of_fft/2-lwr_cut_off)/N_of_bins)) + 30*log10((2:N_of_bins)) );

bin_height = zeros(1,N_of_bins); %initialize to height one
bin_height_lazy = zeros(1,N_of_bins); %initialize to height one
height_latency = zeros(1,N_of_bins);
difference = zeros(1,N_of_bins);
speed_coeff = 0.3;
max_height = 0;
weights = (1.1.^(0:N_of_bins-1));
forward = 4080;

st_handle = stem(1:N_of_bins,zeros(1,N_of_bins));
st_handle.YData = [];

axis([1 N_of_bins 0 1]);

hold on


data = nan(size_of_fft,1);
sample_rate = 0;

%read file

[audio_sample,sample_rate] = audioread('song5.wav');


for index = 1:size_of_fft/4
    
 (index*forward)/sample_rate
    
%truncate file

data = audio_sample(1+index*forward:size_of_fft+index*forward,1);

%apply window

data = hann(size_of_fft).*data;

% reorder input data

data = data(bitrevorder((0:size_of_fft-1).') + 1,:);


data = 2^10*(0:15).'
data = data(bitrevorder((0:size_of_fft-1).') + 1,:);
%iterate through tree

offset = 0;
temp_E = 0;
temp_O = 0;

    fileID = fopen('log_fft_4.txt', 'w');

for tr_dpth = 1:log2(size_of_fft)
   
    offset = 2^(tr_dpth-1);
    
    for tr_brdth = 1:2^(log2(size_of_fft) - tr_dpth)
       
        for btt_span = 1:2^(tr_dpth-1)
            temp_E = data(2^(tr_dpth)*(tr_brdth - 1) + btt_span,1) + ...
            exp((-1i*2*pi()/size_of_fft)*2^(log2(size_of_fft) - tr_dpth)*(btt_span-1))*data(2^(tr_dpth)*(tr_brdth - 1) + btt_span + offset,1); %X_k = X_k + W_k*X_k+N/2
            temp_O = data(2^(tr_dpth)*(tr_brdth - 1) + btt_span,1) - ...
            exp(-1i*2*pi()/size_of_fft*2^(log2(size_of_fft) - tr_dpth)*(btt_span-1))*data(2^(tr_dpth)*(tr_brdth - 1) + btt_span + offset,1); %X_k+N/2 = X_k - W_k*X_k+N/2
        
            data(2^(tr_dpth)*(tr_brdth - 1) + btt_span,1) = temp_E;
            data(2^(tr_dpth)*(tr_brdth - 1) + btt_span +offset,1) = temp_O;
        end
        
    end
    
    fprintf(fileID, 'iteration number %d :',tr_dpth);
    for t = 1:size_of_fft
        fprintf(fileID, '@i %d : %.1f + j%.1f, ',t-1, real(data(t)), imag(data(t)));
    end
    fprintf(fileID, '\n');
end

fclose(fileID);

%amplitude spectrum
data_trunc = data(1:2^(log2(size_of_fft)-1),1);
data_trunc(1:end,1) = abs(data_trunc(1:end,1));

%sort into frequency bins, calculate difference

bin_height(1) = sum(data_trunc(1:bin_edges(1),1))/length(1:bin_edges(1)); 

for index = 2:N_of_bins-1 
    
    bin_height(index) = sum(data_trunc(bin_edges(index-1):bin_edges(index),1))/length(bin_edges(index-1):bin_edges(index));
    
end

bin_height(N_of_bins) = sum(data_trunc(bin_edges(N_of_bins-1):length(data_trunc),1))/length(bin_edges(N_of_bins-1):length(data_trunc));

bin_height_lazy = bin_height_lazy + speed_coeff*(bin_height - bin_height_lazy);

bin_height_lazy_w = bin_height_lazy.*weights;

if max(bin_height_lazy_w) > max_height
    max_height = max(bin_height_lazy_w);
end

bin_height_lazy_w = bin_height_lazy_w/max_height;


%display

st_handle.YData = bin_height_lazy_w;
%stem(1:N_of_bins,bin_height_lazy)

%semilogx(lwr_cut_off:length(data_trunc),data_trunc(lwr_cut_off:end,1));
pause(0.01);
drawnow 

end


