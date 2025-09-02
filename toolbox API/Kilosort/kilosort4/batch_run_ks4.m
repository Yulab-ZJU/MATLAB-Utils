ccc;

%% Path settings
EXCELPATH = '~\temp.xlsx';
SAVEROOTPATH = '~\DATA\MAT DATA\';

%% Parameter settings
% user-specified
sortIDs = [1, 2]; % which id to sort
th = [9, 8]; % [Th_universal, Th_learned]

skipBinExportExisted = true;
skipSortExisted = true;
skipMatSaveExisted = true;

% fixed
FORMAT = 'i16'; % data type, default='i16' (int16)

sortIDs = unique(sortIDs);

%% Step-1 Convert to binary data file
[BINPATHs, TRIGPATHs, nch] = mu_ks4_exportBins(EXCELPATH, sortIDs, FORMAT, skipBinExportExisted);

%% Step-2 Run kilosort4
RESPATHs = mu_ks4_runKilosort4(BINPATHs, EXCELPATH, sortIDs, FORMAT, th, skipSortExisted);

%% Step-3 Export sort results to MAT
% ------------ Export spikes ---------------
% Get data length of each binary file
nsamples = cellfun(@(x) cellfun(@(y) mu_ks_getBinDataLength(y, nch, FORMAT), x), BINPATHs, "UniformOutput", false);

% Get realigned spike times and channel-related cluster index
[spikeTimes, clusterIdxs, dataTDT, tShift] = ...
    mu_ks4_exportSpkMat(EXCELPATH, ...
                        sortIDs, ...
                        SAVEROOTPATH, ...
                        RESPATHs, ...
                        TRIGPATHs, ...
                        nsamples, ...
                        skipMatSaveExisted);

% --------------- Export LFP -----------------

