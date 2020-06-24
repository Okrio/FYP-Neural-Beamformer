%--------------------------------------------------------------------------
% Example script for DSB response of a single frequency sinusoid input
% Author        : Jinming Hu
% Date          : 05-05-2020
% Version       : Final
%--------------------------------------------------------------------------
%% Parameter Settings
clc;
close all;
clear variables;
set(0,'DefaultAxesFontSize',11)
set(0,'DefaultLineLineWidth',1);

c = 340;                % Sound velocity (m/s)
n = 1024;               % Number of samples for RIR Default:1024
beta = 0;               % Reverberation time (s) Default:0
Room = [8 8 4];			% Room dimensions [x y z] (m) 

Fs = 16000;             % Sample frequency (samples/s) 
T = 1/Fs;               % Sampling period (s)       
L = 1600;               % Length of signal
t = (0:L)*T;          % Time vector

Mic_number = 6;         % Number of microphones Default:6
Mic_spacing = 0.15;     % Spacing of microphones (m) Default:0.15

source_degree = 360;    % Angle of source need to plot
source_resolution = 1;  % Angle difference of each source
source_radius = 1;      % Radius of the source to the center of the array Default:2

steering_angle = 45;
source_frequency = 2000;

%% Create source and receivers

r = CreateReceiverPosition(Mic_number,Mic_spacing,Room(1),Room(2),Room(3)); % Generate receiver position [x y z] (m)
s = CreateSourcePosition(source_degree,source_resolution, source_radius, Room(1), Room(2), Room(3)); % Generate source position [x y z] (m)
% PlotSourceReceiverPosition(Room,r,s); % [Figure] Plot the position of source and receiver in the room

source_angle = 0:source_resolution:source_degree; 
source_input = cos(2*pi*source_frequency*t); 
% power = sum(abs(source_input).^2)/length(source_input); % Power = 0.5*amp for cos, except 0 Hz

signal_output_DSB_gain = zeros(1,size(s,1));
signal_output_DSB_power = zeros(1,size(s,1));

for source_index = 1:size(s,1) % for each source
    RIR = FindRoomImpulseResponse(c, Fs, r, s(source_index,:), Room, beta, n); 
%     PlotRIR(RIR,Mic_number); % [Figure] Plot the RIR, remember to add break point
    source_input_rir = ConvWithRIR(source_input,RIR);
    power_input = sum(sum(abs(source_input_rir).^2))/length(source_input_rir)/Mic_number;
    
    time_length = length(source_input_rir(1,:)); 
    if mod(time_length,2) == 0 % N is even
        frequency_bin1 = (0:((time_length)/2))*Fs/(time_length); 
        frequency_bin2 = [frequency_bin1,fliplr(-frequency_bin1(2:end-1))];    
    else % N is odd 
        frequency_bin1 = (0:((time_length-1)/2))*Fs/(time_length-1); 
        frequency_bin2 = [frequency_bin1,fliplr(-frequency_bin1(2:end))];
    end
    
    signal_input_freq = fft(source_input_rir.').';  % perform fft 
    weights_DSB = FindWeightsDSB(r,Mic_spacing,frequency_bin2,steering_angle,c); % calculate weights of DSB
    signal_output_DSB_freq = sum(weights_DSB.*signal_input_freq); % multiply the weights and add all the channels together
    signal_output_DSB_time = ifft(signal_output_DSB_freq);
   
    output_power = sum(abs(signal_output_DSB_time).^2)/length(signal_output_DSB_time);
    signal_output_DSB_power(source_index) = output_power;
    
    output_gain = (output_power/power_input);
    signal_output_DSB_gain(source_index) = output_gain;
end

figure;
plot(source_angle,10*log10(signal_output_DSB_gain));
xlabel("Angle/degree"); ylabel("Gain/dB");
title('DSB Output Gain of 1000 Hz sinusoidal signal'),xlim([0 360]);

figure;
output_gain_dB = 10*log10(signal_output_DSB_gain);
output_gain_dB = output_gain_dB - max(output_gain_dB);
output_gain_dB(output_gain_dB<-40) = -40;
h = polarplot(source_angle*pi/180,output_gain_dB+40,'Linewidth',1);
haxes = get(h,'Parent');
haxes.RTickLabel = {'-40','-30','-20','-10','0 dB'};
title("Polar plot of DSB output gain of 1000 Hz sinusoidal signal");

%% Plots
function PlotSourceReceiverPosition(Room,receiver_position,source_position)
    figure;
    plot3(receiver_position(:,1),receiver_position(:,2),receiver_position(:,3),'o'); % scatter3(s(:,1),s(:,2),s(:,3));
    hold on;
    plot3(source_position(:,1),source_position(:,2),source_position(:,3),'r.'); % scatter3(r(:,1),r(:,2),r(:,3)); 
    legend('Microphones','Signal Source');
    axis([0 Room(1) 0 Room(2) 0 Room(3)]);
    xlabel("x-axis/m"); ylabel("y-axis/m"); zlabel("z-axis/m");
    title("Position of source and microphone array");
    grid on; box on; axis square;hold off;
end

function PlotRIR(RIR,Mic_number)
    figure;
    for i = 1:Mic_number
        rir_plot = subplot(2,Mic_number/2,i);
        plot(RIR(i,:));
        title(rir_plot, ['Room impulse response of the ',num2str(i),'th microphone'])
        xlabel("Samples"); ylabel("Amplitude");
    end
    figure;
    plot(RIR');
    title('Room impulse response of the microphone array')
    xlabel("Samples"); ylabel("Amplitude");
end

%% Functions
function receiver_position = CreateReceiverPosition(Mic_number,Micro_Spacing,x,y,z)
    receiver_position = zeros(Mic_number,3); % A matrix with size nMic x 3, 3 for three axis x ,y, z
    Array_length = Micro_Spacing*(Mic_number-1);
    for index = 1:Mic_number
        receiver_position(index,:) = [(x-Array_length)/2+(index-1)*Micro_Spacing y/2 z/2]; % Microphones'position different in x axis
    end
end

function source_position = CreateSourcePosition(source_degree,source_resolution,radius,x,y,z) 
    source_position = zeros(source_degree/source_resolution+1,3); % eg. 360/60+1, 1 more for 0 degree
    source_angle = 0:source_resolution*pi/180:source_degree*pi/180;
    for index = 1:source_degree/source_resolution+1
        source_position(index,:) = [x/2+radius*cos(source_angle(index)) y/2+radius*sin(source_angle(index)) z/2]; 
    end
end

function rir_array = FindRoomImpulseResponse(c, fs, receiver_position, source_position, Room, beta, n) 
    Mic_number = size(receiver_position,1);    
    rir_array = zeros(Mic_number,n);
    for index = 1:Mic_number
        h = rir_generator(c, fs, receiver_position(index,:), source_position, Room, beta, n); 
        rir_array(index,:) = h;
    end
end

function signal_output = ConvWithRIR(signal_input,RIR) 
    Mic_number = size(RIR,1); 
    sample_number = size(signal_input,2);
    signal_output = zeros(Mic_number,sample_number);
    for index = 1:Mic_number
        signal_output(index,:) = filter(RIR(index,:),1,signal_input); 
    end
end

function weights_DSB = FindWeightsDSB(Receiver_position, Mic_spacing, frequency_array, steering_angle, c)
    Mic_number = size(Receiver_position,1);
    frequency_upperbound = length(frequency_array);
    weights_DSB = zeros(Mic_number,frequency_upperbound);
    for Mic_index = 1:Mic_number  % for each microphone
        for frequency_index = 1:frequency_upperbound  % for each frequency
            weights_DSB(Mic_index,frequency_index) = 1/Mic_number*exp(-1*1i*frequency_array(frequency_index)*2*pi/c*Mic_spacing*(Mic_index-1)*cos(steering_angle*pi/180)); 
        end
    end
end
