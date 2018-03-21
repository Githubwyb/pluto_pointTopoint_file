function recvTimerCb(s, inputPluto)
    persistent isFirst;
    persistent lastSeq;
    persistent seqNum;
    persistent filedata;
    persistent filename;
    persistent fileSize;

    if isempty(isFirst)
        isFirst = 1;
        lastSeq = 0;
        seqNum = 0;
        filedata = [];
        filename = '';
        fileSize = 0;
    end

    rStr = '';
    output = recieve_data(s);
    I = output{1};
    Q = output{2};
    Rx = I + 1i * Q;

    [rStr, isRecieved] = bpsk_rx_func(Rx(end / 2 : end));
    if (~isRecieved)
        return;
    else
        [dataType, seqNum, dataLen, recvData] = parsePack(rStr);
        if dataType == 1
            return;
        end
        if isFirst == 1
            isFirst = 0;
            lastSeq = seqNum + 1;
        end

        if lastSeq ~= seqNum
            disp(rStr);

            switch dataType
                case 0
                    fprintf('recieve string: %s\n', char(recvData));

                case 2
                    if recvData(1) == 0
                        fileSize = recvData(2);
                        filename = char(recvData(3 : end));
                        fprintf('receive file, name: %s\n', filename);
                    elseif recvData(1) <= fileSize
                        fprintf('receive file pack, seq: %d, full: %d\n', recvData(1), fileSize);
                        filedata((recvData(1) - 1) * 50 + 1 : (recvData(1) - 1) * 50 + dataLen - 1) = recvData(2 : dataLen);
                        %disp(filedata);
                        if recvData(1) == fileSize
                            fid = fopen('test.txt', 'wb');
                            fwrite(fid, filedata, 'unsigned char');
                            fclose(fid);
                            filedata = [];
                        end
                    end

                otherwise
                    return;
            end
        end

        lastSeq = seqNum;
        sendData = [1, uint8(seqNum)];
        txdata = bpsk_tx_func(sendData);
        txdata = round(txdata .* 2^14);
        txdata = repmat(txdata, 8, 1);
        inputPluto{1} = real(txdata);
        inputPluto{2} = imag(txdata);
        send_data(s, inputPluto);
    end
end