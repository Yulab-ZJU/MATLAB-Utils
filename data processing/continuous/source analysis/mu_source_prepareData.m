function [data, data_erp, data_cov] = mu_source_prepareData(trialsData, window, fs, channelNames)
% This function converts cell data to fieldtrip format.
% For EEG data with electrode labels, specify channel names.
% Input:
%   [trialsData]: trial data (cell)
%   [window]: time window, in ms
%   [fs]: sample rate, in Hz
%   [channelNames]: electrode labels

narginchk(3, 4);

if isa(trialsData, "double") % single trial / ERP
    trialsData = {trialsData};
end

t = linspace(window(1), window(2), size(trialsData{1}, 2)) / 1000; % s
channels = (1:size(trialsData{1}, 1))';

if nargin < 4
    channelNames = arrayfun(@num2str, channels, "UniformOutput", false);
else

    if numel(channelNames) ~= numel(channels)
        error("The number of channel labels does not match the number of channels");
    end

end

% trial data
cfg = [];
cfg.reref = 'yes';               % use re-reference
cfg.refmethod = 'average';       % CAR
cfg.refchannel = 'all';
cfg.trials = 'all';
data.trial = trialsData(:)';
data.time = repmat({t}, 1, length(trialsData));
data.label = channelNames;
data.fsample = fs;
data.trialinfo = ones(length(trialsData), 1);
data = ft_selectdata(cfg, data);

% ERP
cfg = [];
cfg.trials = 'all';
data_erp = ft_timelockanalysis(cfg, data);

% Covariance
cfg = [];
cfg.covariance = 'yes';
cfg.covariancewindow = 'all';
data_cov = ft_timelockanalysis(cfg, data);

return;
end