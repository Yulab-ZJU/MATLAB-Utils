function [comp, ICs] = ica_loop(trialsData, windowICA, fs, varargin)
% Description: perform ICA on data and loop reconstructing data with input ICs until you are satisfied
% Input:
%   REQUIRED
%     trialsData: ntrial*1 cell of trial data ([nch x nsample])
%     windowICA: time window for trial data, in ms
%     fs: sample rate, in Hz
%     topo: [nX,nY] for an array or [EEGPos] struct (see EEGPos_Neuracle64.m)
%   OPTIONAL
%     chs2doICA: channel number to perform ICA on (e.g. [1:25,27:64], default='all')
%   NAMEVALUE
%     'Method': ICA method, 'runica' or 'fastica' (default='runica')
% Output:
%     comp: result of ICA (FieldTrip) without field [trial]
%     ICs: the input IC number vector for data reconstruction

%% Validate parameters
mIp = inputParser;
mIp.addRequired("trialsData", @(x) validateattributes(x, 'cell', {'vector'}));
mIp.addRequired("windowICA", @(x) validateattributes(x, {'numeric'}, {'2d', 'increasing'}));
mIp.addRequired("fs", @(x) validateattributes(x, 'numeric', {'scalar', 'positive'}));
mIp.addRequired("topo");
mIp.addOptional("chs2doICA", 'all');
mIp.addParameter("Method", 'runica', @(x) any(validatestring(x, {'runica', 'fastica'})));
mIp.parse(trialsData, windowICA, fs, topo, varargin{:});

[nch, nsample] = mu.checkdata(trialsData);
channels = (1:nch)';

chs2doICA = mIp.Results.chs2doICA;
if strcmpi(chs2doICA, 'all')
    chs2doICA = channels;
else
    validateattributes(chs2doICA, 'numeric', {'vector', 'positive', 'integer'});
    temp = channels;
    temp(~ismember(channels, chs2doICA(:))) = [];
    chs2doICA = arrayfun(@num2str, temp, "UniformOutput", false);
end
badCHs = channels(~ismember(channels, chs2doICA));

%% Perform ICA
comp = ica(trialsData, windowICA, fs, varargin{:});

%% Plot ICA result
% IC Wave
FigIC = plotRawWave(mu.calchMean(comp.trial), mu.calchStd(comp.trial), windowICA, "ICA");
mu.scaleAxes(FigIC, "y", "on", "symOpt", "max", "autoTh", [0.01, 0.99], "cutoffRange", [-50, 50], "uiOpt", "show");

% IC topo
topo = mu.insertrows(comp.topo, badCHs);
plotTopoICA(topo, [8, 8]);

% Origin raw wave
temp = interpolateBadChs(trialsData, badCHs);
FigWave(1) = plotRawWave(calchMean(temp), calchStd(temp), windowICA, "origin");
scaleAxes(FigWave(1), "y", "cutoffRange", [-100, 100], "symOpts", "max");

% Remove bad channels in trialsData
trialsData = cellfun(@(x) x(chs2doICA, :), trialsData, "UniformOutput", false);

k = 'N';
while ~any(strcmpi(k, {'y', ''}))
    try
        close(FigWave(2));
    end

    ICs = input('Input IC number for data reconstruction (empty for all): ');
    if isempty(ICs)
        ICs = 1:length(chs2doICA);
    end
    badICs = input('Input bad IC number: ');
    ICs(ismember(ICs, badICs)) = [];

    temp = reconstructData(trialsData, comp, ICs);
    temp = cellfun(@(x) insertRows(x, badCHs), temp, "UniformOutput", false);
    temp = interpolateBadChs(temp, badCHs);
    FigWave(2) = plotRawWave(calchMean(temp), calchStd(temp), windowICA, "reconstruct");
    scaleAxes(FigWave(2), "y", "on", "symOpts", "max");

    k = validateInput('Press Y or Enter to continue or N to reselect ICs: ', @(x) isempty(x) || any(validatestring(x, {'y', 'n', 'N', 'Y', ''})), 's');
end

comp.trial = [];
comp.chs2doICA = chs2doICA;

return;
end