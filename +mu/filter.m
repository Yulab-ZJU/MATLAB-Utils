function data = filter(data, fs, varargin)
% FILTER General zero-phase multi-channel filter for trial or matrix data.
%
% This function applies zero-phase filtering to multi-channel data using the FieldTrip toolbox
% and MATLAB built-in functions (`filtfilt` and `designNotchPeakIIR`, MATLAB R2023b or newer).
% It supports high-pass, low-pass, and notch filtering. If a filter frequency is not specified,
% that filter type will not be applied.
%
% INPUTS:
%   data    - Cell array of trial data, or a 2D matrix [nch, nsample]
%   fs      - Sampling rate in Hz
%   Name-Value pairs:
%     "fhp"    - High-pass filter cutoff frequency (Hz, scalar)
%     "flp"    - Low-pass filter cutoff frequency (Hz, scalar)
%     "fnotch" - Notch filter stop frequency (Hz, vector)
%     "order"  - Butterworth filter order (integer, default: 3)
%     "BW"     - Notch filter bandwidth (Hz, default: 1)
%
% OUTPUT:
%   data    - Filtered data, same type as input
%
% NOTES:
%   - If a filter frequency is not specified, that filter will be skipped.
%   - Supports both single-trial and multi-trial data.
%   - Requires FieldTrip toolbox.
%
% Example:
%   data_filt = mu.filter(data, fs, "fhp", 1, "flp", 40, "fnotch", [50, 100]);

%% Validation
mIp = inputParser;
mIp.addRequired("data", @(x) validateattributes(x, {'numeric', 'cell'}, {'2d'}));
mIp.addRequired("fs", @(x) validateattributes(x, {'numeric'}, {'scalar', 'positive'}));
mIp.addParameter("fhp", [], @(x) validateattributes(x, {'numeric'}, {'scalar', 'positive', '<', fs / 2}));
mIp.addParameter("flp", [], @(x) validateattributes(x, {'numeric'}, {'scalar', 'positive', '<', fs / 2}));
mIp.addParameter("fnotch", [], @(x) validateattributes(x, {'numeric'}, {'vector', 'positive', '<', fs / 2}));
mIp.addParameter("order", 3, @(x) validateattributes(x, {'numeric'}, {'scalar', 'integer', 'positive'}));
mIp.addParameter("BW", 1, @(x) validateattributes(x, {'numeric'}, {'scalar', 'positive'}));
mIp.parse(data, fs, varargin{:});

order = mIp.Results.order;
BW = mIp.Results.BW;
fhp = mIp.Results.fhp;
flp = mIp.Results.flp;
fnotch = mIp.Results.fnotch;

%% Init parameters and data
% Nyquist frequency
fnyq = fs / 2;

% To avoid function name conflit
filtfilt = mu.path2func(fullfile(matlabroot, "toolbox/signal/signal/filtfilt.m"));

% Convert data to cell array
datatype = class(data);
switch datatype
    case {'single', 'double'} % nch_nsample
        [nch, nsample] = size(data);
        data = {data};
    case 'cell' % ntrial (nch_nsample)
        [nch, nsample] = size(data{1});
        data = data(:); % column vector
    otherwise
        error("Invalid data type");
end

t = (1:nsample) / fs;
ntrial = numel(data);

%% Bandpass filtering - Use fieldtrip filter
if ~isempty(fhp) || ~isempty(flp)
    cfg = [];
    cfg.trials = 'all';
    dataTemp.trial = data(:)';
    dataTemp.time = repmat({t}, 1, ntrial);
    dataTemp.label = compose('%d', (1:nch)');
    dataTemp.fsample = fs;
    dataTemp = ft_selectdata(cfg, dataTemp);

    cfg = [];
    cfg.demean = 'no';
    if ~isempty(fhp)
        cfg.hpfilter = 'yes';
        cfg.hpfreq = fhp;
        cfg.hpfiltord = order;
    end
    if ~isempty(flp)
        cfg.lpfilter = 'yes';
        cfg.lpfreq = flp;
        cfg.lpfiltord = order;
    end
    dataTemp = ft_preprocessing(cfg, dataTemp);

    data = dataTemp.trial(:); % column vector
end

%% Notch filtering
if ~isempty(fnotch)
    % Convert data to [nsample, nch]
    data = cellfun(@(x) x', data, "UniformOutput", false);

    % Notch
    for fIndex = 1:length(fnotch)
        [b, a] = designNotchPeakIIR(Response = "notch", ...
                                    CenterFrequency = fnotch(fIndex) / fnyq, ...
                                    Bandwidth = BW / fnyq, ...
                                    FilterOrder = 2);
        data = cellfun(@(x) filtfilt(b, a, x)', data, "UniformOutput", false);
    end
end

%% Recover data type
if ~strcmp(datatype, 'cell')
    data = data{1};
end

return;
end