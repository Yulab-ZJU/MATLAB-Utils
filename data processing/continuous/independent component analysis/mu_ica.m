function [comp, ICs] = mu_ica(trialsData, windowICA, fs, topo, varargin)
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

[nch, ~] = mu.checkdata(trialsData);
channels = (1:nch)';

chs2doICA = mIp.Results.chs2doICA;
if strcmpi(chs2doICA, 'all')
    chs2doICA = channels;
else
    validateattributes(chs2doICA, 'numeric', {'vector', 'positive', 'integer'});
    temp = channels;
    temp(~ismember(channels, chs2doICA(:))) = [];
    chs2doICA = temp;
end
badChs = channels(~ismember(channels, chs2doICA));

%% Perform ICA
comp = mu_ica_impl(trialsData, windowICA, fs, varargin{:});

%% Plot ICA result
% IC Wave
mu_plotWaveArray(struct("chMean", mu.calchMean(comp.trial), "chErr", mu.calchStd(comp.trial)), windowICA);
mu.addTitle("IC");
mu.scaleAxes("y", "on", "symOpt", "max", "autoTh", [0, 1], "cutoffRange", [-50, 50]);

% IC distribution
if isstruct(topo)
    % EEG
    EEGPos = topo;
    neighbours = EEGPos.neighbours;
    mu_ica_topoplotEEG(mu.insertrows(comp.topo, badChs), EEGPos);
    trialsDataInterp = mu_interpolateBadChannels(trialsData, badChs, neighbours);
else
    % Electrode Array
    topoSize = topo;
    neighbours = mu_prepareNeighboursArray(channels, topoSize, "orthogonal");
    mu_ica_topoplotArray(mu.insertrows(comp.topo, badChs), topoSize);
    trialsDataInterp = mu_interpolateBadChannels(trialsData, badChs, neighbours);
end

% Origin raw wave
if isstruct(topo)
    mu_plotWaveEEG(struct("chMean", mu.calchMean(trialsDataInterp), "chErr", mu.calchStd(trialsDataInterp)), windowICA, EEGPos);
else
    mu_plotWaveArray(struct("chMean", mu.calchMean(trialsDataInterp), "chErr", mu.calchStd(trialsDataInterp)), windowICA, "GridSize", topoSize);
end
mu.addTitle("Original");
mu.scaleAxes("y", "on", "symOpts", "max", "autoTh", [0, 1], "cutoffRange", [-50, 50]);

% Remove bad channels in trialsData
trialsData = cellfun(@(x) x(chs2doICA, :), trialsData, "UniformOutput", false);

k = 'N';
while ~any(strcmpi(k, {'y', ''}))
    try
        close(FigWave);
    end

    ICs = input('Input IC number for data reconstruction (empty for all): ');
    if isempty(ICs)
        ICs = 1:size(comp.topo, 2);
    end
    badICs = input('Input bad IC number: ');
    ICs = setdiff(ICs, badICs);

    temp = mu_ica_reconstructData(trialsData, comp, ICs);
    temp = cellfun(@(x) mu.insertrows(x, badChs), temp, "UniformOutput", false);
    temp = mu_interpolateBadChannels(temp, badChs, neighbours);
    
    if isstruct(topo)
        FigWave = mu_plotWaveEEG(struct("chMean", mu.calchMean(temp), "chErr", mu.calchStd(temp)), windowICA, EEGPos);
    else
        FigWave = mu_plotWaveArray(struct("chMean", mu.calchMean(temp), "chErr", mu.calchStd(temp)), windowICA, "GridSize", topoSize);
    end
    mu.addTitle(FigWave, "Reconstruct");
    mu.scaleAxes(FigWave, "y", "on", "symOpts", "max", "autoTh", [0, 1]);

    k = validateinput('Press Y or Enter to continue or N to reselect ICs: ', @(x) isempty(x) || any(validatestring(x, {'y', 'n', 'N', 'Y', ''})), 's');
end

comp = rmfield(comp, ["trial", "time"]);
comp.chs2doICA = chs2doICA;

return;
end