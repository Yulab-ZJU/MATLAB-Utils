function [datPATHs, TRIGPATHs] = NP2bins(datPATHs, skipBinExportExisted)

datPATHs = cellstr(datPATHs);
TRIGPATHs = cell(numel(datPATHs), 1);
for dIndex = 1:numel(datPATHs)
    % normalize
    DATAPATH = mu.getabspath(datPATHs{dIndex});
    TRIGPATHs{dIndex} = fullfile(fileparts(datPATHs, 'TTL.mat'));

    % get full path
    if ~endsWith(DATAPATH, 'continuous.dat')
        datPATHs{dIndex} = fullfile(DATAPATH, 'continuous.dat');
    end
    
    if skipBinExportExisted && exist(TRIGPATHs{dIndex}, "file")
        continue;
    end

    % get data length
    nch = 385;
    dataLength = mu_ks_getBinDataLength(datPATHs{dIndex}, nch, 'i16');
    trigger = memmapfile(datPATHs{dIndex}, 'Format', {'int16', [nch, dataLength], 'x'});
    TTL = trigger.Data.x(end, :);
    save(TRIGPATHs{dIndex}, "TTL", "-v7.3");
end

return;
end