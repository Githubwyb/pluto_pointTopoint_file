clearvars -except times;close all;warning off;
clear;
clc;
set(0,'defaultfigurecolor','w');
addpath .\library
addpath .\library\matlab

ip = '192.168.2.1';
addpath BPSK\transmitter
addpath BPSK\receiver

%% System Object Configuration
s = iio_sys_obj_matlab; % MATLAB libiio Constructor
s.ip_address = ip;
s.dev_name = 'ad9361';
s.in_ch_no = 2;
s.out_ch_no = 2;
s.in_ch_size = 42568;
s.out_ch_size = 42568 * 8;

s = s.setupImpl();

inputPluto = cell(1, s.in_ch_no + length(s.iio_dev_cfg.cfg_ch));
output = cell(1, s.out_ch_no + length(s.iio_dev_cfg.mon_ch));

% Set the attributes of AD9361
inputPluto{s.getInChannel('RX_LO_FREQ')} = 2e9;
inputPluto{s.getInChannel('RX_SAMPLING_FREQ')} = 40e6;
inputPluto{s.getInChannel('RX_RF_BANDWIDTH')} = 20e6;
inputPluto{s.getInChannel('RX1_GAIN_MODE')} = 'manual';%% slow_attack manual
inputPluto{s.getInChannel('RX1_GAIN')} = 10;
% inputPluto{s.getInChannel('RX2_GAIN_MODE')} = 'slow_attack';
% inputPluto{s.getInChannel('RX2_GAIN')} = 0;
inputPluto{s.getInChannel('TX_LO_FREQ')} = 2e9;
inputPluto{s.getInChannel('TX_SAMPLING_FREQ')} = 40e6;
inputPluto{s.getInChannel('TX_RF_BANDWIDTH')} = 20e6;

%% Transmit and Receive using MATLAB libiio

seqNum = 0;

flagSuccess = 0;

dataType = 0;
dataLen = 0;

fileSeq = 0;
fileSeqSum = 0;

state = 0;

recvTask = timer('TimerFcn','recvTimerCb(s, inputPluto)', 'Period', 0.1, 'ExecutionMode', 'fixedSpacing');

start(recvTask);

while true
    switch state
        case 0
            sendType = input('input send type: ', 's');
            switch sendType
                case 'file'
                    dataType = uint8(2);
                    filename = input('input filename: ', 's');
                    fid = fopen(filename, 'rb');
                    if fid < 0
                        fprintf('file open failed\n');
                        continue;
                    else
                        [filedata, filesize] = fread(fid, inf, 'uint8');
                        filedata = filedata';
                        if filesize == 0
                            fprintf('file read failed\n');

                        elseif filesize >= 50 * 255
                            fprintf('file is too big\n');

                        else
                            fileSeq = 0;
                            fileSeqSum = ceil(filesize / 50);
                            state = 1;
                        end

                        fclose(fid);
                        continue;
                    end

                case 'string'
                    sendData = input('input string: ', 's');

                otherwise
                    fprintf('input error, (file, string)\n');
                    continue;
            end

        case 1
            sendData = [uint8(fileSeq), uint8(fileSeqSum), filename];
            state = 2;
            fileSeq = fileSeq + 1;

        case 2
            if fileSeq < fileSeqSum
                sendData = [uint8(fileSeq), filedata((fileSeq - 1) * 50 + 1 : fileSeq * 50)];
                fileSeq = fileSeq + 1;
            elseif fileSeq == fileSeqSum
                sendData = [uint8(fileSeq), filedata((fileSeq - 1) * 50 + 1 : end)];
                state = 0;
            end

        otherwise
            state = 0;
            continue;
    end

    sendPack = [dataType, uint8(seqNum), length(sendData), sendData];
    %disp(sendData);
    txdata = bpsk_tx_func(sendPack);
    txdata = round(txdata .* 2^14);
    txdata = repmat(txdata, 8, 1);
    inputPluto{1} = real(txdata);
    inputPluto{2} = imag(txdata);
    flagSuccess = 0;

    while flagSuccess == 0
        send_data(s, inputPluto);

        sendTime = clock;
        while (etime(clock, sendTime) < 10)
            output = recieve_data(s);
            I = output{1};
            Q = output{2};
            Rx = I + 1i * Q;

            [rStr, isRecieved] = bpsk_rx_func(Rx(end / 2 : end));
            if (~isRecieved)
                continue;
            elseif (rStr(1) == 1 && rStr(2) == seqNum)
                fprintf('send data success\n');
                fprintf('=============================\n');
                flagSuccess = 1;
                seqNum = seqNum + 1;
                if seqNum == 256
                    seqNum = 0;
                end
                break;
            end
        end

        if(flagSuccess == 0)
            fprintf('timeout, resend data\n');
        end
    end
end

fprintf('Transmission and reception finished\n');
fprintf('recievedData: %s\n', recievedStr);

% Read the RSSI attributes of both channels
rssi1 = output{s.getOutChannel('RX1_RSSI')};
% rssi2 = output{s.getOutChannel('RX2_RSSI')};

s.releaseImpl();
