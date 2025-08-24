ccc;

%% Paths
recordExcelPath = 'D:\Lab members\Public\code\MultiChannelProcess\utils\recordingExcel\XHX\XHX_RNP_Recording.xlsx';

%% Parameters
sortIDs = 1;


params = getParams(recordExcelPath, sortIDs);

%% Step1 convert data to merged bin file
% loop for each sort ID
for index = 1:numel(params)
    sorted = params.sort;

    % skip sorted
    if all(sorted)
        continue;
    end

    BLOCKPATHs = params.BLOCKPATH;
    DATAPATHs = params.datPath;
    sitePos = params.sitePos;
    fs = params.SR_AP;
    recTech = params.recTech;
    nCh = params.chNum;
    badChs = params.badChannel;

    % find corresponding electrode configuration
    switch recTech
        
    end
end



[settings, opts] = config_kilosort4(...
    "n_chan_bin", 385, ...
    "fs", 30e3, ...
    "Th_universal", 9, ... Th(1)
    "Th_learned", 8, ... Th(2)
    "data_dtype", 'int16', ...
    "filename", fullfile(pwd, 'ZFM-02370_mini.imec0.ap.short.bin'), ...
    "probe_name", fullfile(pwd, 'NeuroPix1_default.mat'));