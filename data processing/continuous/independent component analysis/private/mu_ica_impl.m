function comp = mu_ica_impl(trialsData, windowICA, fs, varargin)
% Description: Perform ICA on trial data.
% Input:
%   REQUIRED
%     trialsData: ntrial*1 cell of trial data ([nch x nsample])
%     windowICA: time window for trial data, in ms
%     fs: sample rate, in Hz
%   OPTIONAL
%     chs2doICA: channel number to perform ICA on (e.g. [1:25,27:64], default='all')
%   NAMEVALUE
%     'Method': ICA method, 'runica' or 'fastica' (default='runica')
% Output:
%     comp: result of ICA (FieldTrip)

mIp = inputParser;
mIp.addRequired("trialsData", @(x) validateattributes(x, 'cell', {'vector'}));
mIp.addRequired("windowICA", @(x) validateattributes(x, {'numeric'}, {'2d', 'increasing'}));
mIp.addRequired("fs", @(x) validateattributes(x, 'numeric', {'scalar', 'positive'}));
mIp.addOptional("chs2doICA", 'all');
mIp.addParameter("Method", 'runica', @(x) any(validatestring(x, {'runica', 'fastica'})));
mIp.parse(trialsData, windowICA, fs, varargin{:});

[nch, nsample] = mu.checkdata(trialsData);
ntrial = numel(trialsData);
channels = (1:nch)';

chs2doICA = mIp.Results.chs2doICA;
if ~strcmpi(chs2doICA, 'all')
    validateattributes(chs2doICA, 'numeric', {'vector', 'positive', 'integer'});
    temp = channels;
    temp(~ismember(channels, chs2doICA(:))) = [];
    chs2doICA = arrayfun(@num2str, temp, "UniformOutput", false);
end

method = mIp.Results.Method;

%% Preprocessing
% set FieldTrip path to top
ft_promotepaths;

cfg = [];
cfg.trials = 'all';
data.trial = trialsData(:)';
data.time = repmat({linspace(windowICA(1), windowICA(2), nsample) / 1000}, 1, ntrial);
data.label = arrayfun(@num2str, channels, "UniformOutput", false);
data.fsample = fs;
data.trialinfo = ones(ntrial, 1);
data = ft_selectdata(cfg, data);

%% ICA
cfg = [];
cfg.method = method;
cfg.channel = chs2doICA;
comp = ft_componentanalysis(cfg, data);

disp("ICA done.");
return;
end