ccc;

%% Paths
EXCELPATH = 'D:\Lab members\Public\code\MultiChannelProcess\utils\recordingExcel\XHX\XHX_RNP_Recording.xlsx';

%% Parameters
% user-specified
sortIDs = 1; % which id to sort
th = [8, 4]; % [Th_universal, Th_learned]

skipBinExportExisted = true;
skipSortExisted = true;

FORMAT = 'i16'; % data type, default='i16' (int16)

sortIDs = unique(sortIDs);

% read params from Excel
params = getParamsExcel(EXCELPATH, sortIDs);
recTech = params.recTech;
stiePos = params.sitePos;
fs = params.SR_AP; % Hz

%% Step-1 Convert to binary data file
[BINPATHs, TRIGPATHs, nch] = section_exportBins(EXCELPATH, sortIDs, skipBinExportExisted);

%% Step-2 Run kilosort4
RESPATHs = section_runKilosort4(BINPATHs, EXCELPATH, sortIDs, FORMAT, th, skipSortExisted);

%% Step-3 Export sort results to MAT
% ------------ Export spikes ---------------
% Get data length of each binary file
nsamples = cellfun(@(x) getBinDataLength(x, nch, FORMAT), BINPATHs);

% export LFP



