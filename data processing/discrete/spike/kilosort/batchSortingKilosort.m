ccc;

%% Path settings
EXCELPATH = 'D:\Lab members\Public\code\MultiChannelProcess\utils\recordingExcel\ISH\temp.xlsx';
SAVEROOTPATH = 'D:\Lab members\XHX\kilosort4 API\test Data\';

%% Parameter settings
% user-specified
sortIDs = 2; % which id to sort
th = [8, 4]; % [Th_universal, Th_learned]

skipBinExportExisted = false;
skipSortExisted = true;

% fixed
FORMAT = 'i16'; % data type, default='i16' (int16)

%% Init paths and params
sortIDs = unique(sortIDs);
[params, tbl] = getParamsExcel(EXCELPATH, sortIDs);

BLOCKPATHs = params.BLOCKPATH;
sitePos = params.sitePos;
fs = params.SR_AP; % Hz

[~, TANKNAMEs, ~] = cellfun(@(x) mu.getlastpath(x, 3), BLOCKPATHs, "UniformOutput", false);
TANKNAMEs = cellfun(@(x) mu.cellcat(1, join(x(1:2), filesep)), TANKNAMEs, "UniformOutput", false);
SAVEPATHs = cellfun(@(x, y) fullfile(SAVEROOTPATH, 'CTL_New', x, [y, '_', sitePos]), params.paradigm, TANKNAMEs, "UniformOutput", false);

%% Step-1 Convert to binary data file
[BINPATHs, TRIGPATHs, nch] = section_exportBins(EXCELPATH, sortIDs, FORMAT, skipBinExportExisted);

%% Step-2 Run kilosort4
RESPATHs = section_runKilosort4(BINPATHs, EXCELPATH, sortIDs, FORMAT, th, skipSortExisted);

%% Step-3 Export sort results to MAT
% ------------ Export spikes ---------------
% Get data length of each binary file
nsamples = cellfun(@(x) getBinDataLength(x, nch, FORMAT), BINPATHs);

% Get realigned spike times and channel-related cluster index
[spikeTimes, clusterIdxs, dataTDT, tShift] = section_exportSpkMat(RESPATHs, TRIGPATHs, BLOCKPATHs, nsamples, fs);

% Save to MAT file
for rIndex = 1:numel(RESPATHs)
    data = [];
    data.epocs = dataTDT(rIndex).epocs;
    data.sortdata = [spikeTimes{rIndex}, clusterIdxs{rIndex}];
    data.fs = fs;
    data.params = params(rIndex);
    save(fullfile(SAVEPATHs{rIndex}, 'spkData.mat'), "data");

    % update Excel
    idx = find(tbl.ID == sortIDs);
    tbl(idx(rIndex), "spkExported") = 1;
    writetable(tbl, EXCELPATH);
end

% --------------- Export LFP -----------------

