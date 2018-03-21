function [packType, seqNum, dataLen, data] = parsePack(recvData)
    packType = recvData(1);
    seqNum = recvData(2);
    dataLen = recvData(3);
    data = recvData(4 : (3 + dataLen));
end
