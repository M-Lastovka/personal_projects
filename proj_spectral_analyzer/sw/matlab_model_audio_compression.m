%% Audio compression
% author: Martin Lastovka - lastoma4@fel.cvut.cz


%constants declaration & initialization

p =             0.97;    %energy fraction  
fft_len = 2^12;

%read file

[audio_sample,sample_rate] = audioread('song.wav');

N = length(audio_sample);

audio_new = nan(N,1);

%figure;

%if dual channel, truncate
audio_sample = audio_sample(:,1);


for k = 1:round(N/fft_len)-1
    
    dft_samples = fft(audio_sample( (1+(k-1)*fft_len):((k)*fft_len) ));


    % subplot(2,2,1)
    % plot(1:N,audio_sample);
    % title('$\textbf{original signal in time domain}$','interpreter','latex')
    %         grid on
    % subplot(2,2,2)
    % plot(1:N,real(dft_samples))
    % title('$\textbf{real part of original signal spectrum}$','interpreter','latex')
    %         grid on
    % subplot(2,2,3)
    % plot(1:N,imag(dft_samples))
    % title('$\textbf{imaginary part of original signal spectrum}$','interpreter','latex')
    %         grid on

    %save initial energy
    signal_energy_ref = sum(abs(dft_samples(1:end,1)).^2)/fft_len;
    signal_energy_trunc = (abs(dft_samples(1,1))^2)/fft_len;
    index = 1;

    while signal_energy_trunc < signal_energy_ref*p

        index = index + 1;
        %recalculate energy
        signal_energy_trunc = signal_energy_trunc + (2*(abs(dft_samples(index))^2))/fft_len;    
    end


    %truncate

    audio_compressed = dft_samples(1:index,1);

%     fprintf('Size of original sample array in bytes: %d\n Size of compressed array in bytes: %d\n Compression factor: %.2f\n',...
%         length(audio_sample)*8, length(audio_compressed)*16,  (length(audio_compressed)*16)/(length(audio_sample)*8) );
% 
%     save('audio.mat','audio_compressed','N','sample_rate','index','trunc_step');
% 
%     clear;
% 
%     load('audio.mat');

    %reconstruct original waveform (pad zeroes there, where information has been lost)
    dft_samples_uncompressed = [audio_compressed(1:end,1); zeros(1+fft_len - 2*length(audio_compressed),1);...
        conj(audio_compressed(end:-1:2,1))];

    audio_new( (1+(k-1)*fft_len):((k)*fft_len) ) = real(ifft(dft_samples_uncompressed));

%     subplot(2,2,4)
%     plot(1:length(audio_new),audio_new);
%     title('$\textbf{reconstructed signal in time domain}$','interpreter','latex')
%             grid on

end

audiowrite('audio_new.wav',audio_new,sample_rate);
