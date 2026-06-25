function varargout = mu_granger_wavelet_helper(action, varargin)
%MU_GRANGER_WAVELET_HELPER Shared helper functions for wavelet-based GC.
%
% This file intentionally keeps helper functions in one place so that
% mu_granger_wavelet and mu_granger_wavelet_pt use the same implementation.

switch string(action)

    case "prepareData"
        varargout{1} = prepareData_(varargin{:});

    case "impl"
        varargout{1} = impl_(varargin{:});

    case "computeGCFromData"
        varargout{1} = computeGCFromData_(varargin{:});

    case "makeUnionIndex"
        varargout{1} = makeUnionIndex_(varargin{:});

    case "makeWindowIndex"
        varargout{1} = makeWindowIndex_(varargin{:});

    case "averageMap"
        varargout{1} = averageMap_(varargin{:});

    otherwise
        error("mu_granger_wavelet_helper:UnknownAction", ...
            "Unknown helper action: %s", string(action));
end
end

%% ========================================================================
function data = prepareData_(cwtres, f, coi, fs, fRange)
% Prepare data for pairwise Granger causality computation.
%
% cwtres:
%   nTrial x nCh x nFreq x nTime
%
% f:
%   nFreq x 1 frequency vector in Hz, typically descending.
%
% fRange:
%   [] or nRange x 2 frequency ranges in Hz.
%   If multiple ranges are provided, their union is used.

narginchk(4, 5);

if nargin < 5 || isempty(fRange)
    fRange = [];
end

[nTrial, nCh, nFreq, nTime] = size(cwtres);

if numel(f) ~= nFreq
    error("prepareData_:FreqMismatch", ...
        "numel(f) must match size(cwtres, 3).");
end

f = f(:);

%% Optional frequency cropping
if ~isempty(fRange)
    idx = makeUnionIndex_(f, fRange);

    if isempty(idx)
        error("prepareData_:FrequencyRangeNotFound", ...
            "Frequency range not found.");
    end

    f = f(idx);
    cwtres = cwtres(:, :, idx, :);
end

%% Transform frequency scale as in the original implementation
% cwt returns f as descending frequency vector in Hz.
% The original implementation uses 10*log(f) and shifts it to be positive.
fLog = 10 * log(f);
c = 0 - fLog(end);
fLog = fLog + c;

data = struct();
data.freq = fLog;
data.time = (0:nTime - 1) / fs;
data.label = [{'seed'}; cellstr(num2str((1:nCh - 1)'))];
data.dimord = 'rpt_chan_freq_time';
data.cumtapcnt = ones(nTime, numel(fLog));
data.fourierspctrm = cwtres;
data.coi = coi;
data.c = c;

% Store original dimensions for sanity checks.
data.nTrial = nTrial;
data.nCh = nCh;
end

%% ========================================================================
function res = impl_(data)
% Nonparametric pairwise GC implementation.
%
% This function intentionally keeps the original Wilson factorization call:
%   sfactorization_wilson2x2_new
%
% No changes are made to that part.

%% Parameter settings
Niterations = 100;
tol = 1e-18;
checkflag = true;
stabilityfix = true;

%% Channel combinations: seed vs all targets
nLabel = numel(data.label);

cfg = [];
cfg.channelcmb = cat(2, ...
    repmat(data.label(1), [nLabel - 1, 1]), ...
    data.label(2:end));

cfg.cmbindx = [ones(nLabel - 1, 1), (2:nLabel)'];

[nrpt, nchan, ~, ~] = size(data.fourierspctrm);

%% Cross-spectral density
% Original version preallocated data.crsspctrm and then overwrote it.
% Here we avoid that redundant allocation.
data.crsspctrm = pagemtimes( ...
    pagectranspose(data.fourierspctrm), ...
    data.fourierspctrm) ./ nrpt;

%% Wilson spectral factorization
[Htmp, Ztmp, Stmp] = sfactorization_wilson2x2_new( ...
    data.crsspctrm, ...
    data.freq, ...
    Niterations, ...
    tol, ...
    cfg.cmbindx, ...
    checkflag, ...
    stabilityfix);

%% Granger causality
resTmp = struct();
resTmp.freq = data.freq;
resTmp.time = data.time;

resTmp.crsspctrm(1, :, :, :) = Stmp;
resTmp.transfer (1, :, :, :) = Htmp;
resTmp.noisecov (1, :, :, :) = Ztmp;
resTmp.dimord = 'rpt_chancmb_freq_time';

optarg = { ...
    'hasjack', 0, ...
    'method', 'granger', ...
    'powindx', [], ...
    'dimord', resTmp.dimord};

datout = ft_connectivity_granger( ...
    resTmp.transfer, ...
    resTmp.noisecov, ...
    resTmp.crsspctrm, ...
    optarg{:});

% grangerspctrm follows:
%   rows (k-1)*4 + 1: chan1 -> chan1
%   rows (k-1)*4 + 2: chan1 -> chan2
%   rows (k-1)*4 + 3: chan2 -> chan1
%   rows (k-1)*4 + 4: chan2 -> chan2
%
% Keep only between-channel rows.
keepchn = mod(1:size(datout, 1), 4) == 2 | ...
          mod(1:size(datout, 1), 4) == 3;

res = struct();
res.freq = data.freq;
res.time = data.time;
res.grangerspctrm = datout(keepchn, :, :, :, :);

%% channelcmb
nCmb = size(cfg.cmbindx, 1);
channelcmb = cell(nCmb * 2, 2);

for i = 1:nCmb
    channelcmb{2 * i - 1, 1} = 'seed';
    channelcmb{2 * i - 1, 2} = num2str(i);

    channelcmb{2 * i, 1} = num2str(i);
    channelcmb{2 * i, 2} = 'seed';
end

res.channelcmb = channelcmb;
end

%% ========================================================================
function res = computeGCFromData_(dataAll, trialIdx)
% Slice the trial dimension from prepared data and compute GC.
%
% This avoids repeated prepareData calls in permutation tests.

if islogical(trialIdx)
    trialIdx = find(trialIdx);
end

data = dataAll;
data.fourierspctrm = dataAll.fourierspctrm(trialIdx, :, :, :);

% cumtapcnt in this pipeline is not trial-dependent.
% If future versions add trial-dependent fields, slice them here.

res = impl_(data);
end

%% ========================================================================
function idx = makeUnionIndex_(axisVec, ranges)
% Return union index of axisVec within n x 2 ranges.
%
% If ranges is empty, return all indices.

axisVec = axisVec(:);

if isempty(ranges)
    idx = (1:numel(axisVec))';
    return;
end

if ~isnumeric(ranges) || size(ranges, 2) ~= 2
    error("makeUnionIndex_:BadRange", ...
        "ranges must be an n x 2 numeric matrix.");
end

ranges = sort(double(ranges), 2);

mask = false(numel(axisVec), 1);

for i = 1:size(ranges, 1)
    lo = ranges(i, 1);
    hi = ranges(i, 2);

    mask = mask | (axisVec >= lo & axisVec <= hi);
end

idx = find(mask);

if isempty(idx)
    error("makeUnionIndex_:EmptySelection", ...
        "No sample falls within the requested ranges.");
end
end

%% ========================================================================
function wins = makeWindowIndex_(axisVec, ranges, axisName)
% Convert ranges into cell array of indices.
%
% If ranges is empty, each sample is treated as one window.

axisVec = axisVec(:);

if isempty(ranges)
    wins = cell(numel(axisVec), 1);
    for i = 1:numel(axisVec)
        wins{i} = i;
    end
    return;
end

if ~isnumeric(ranges) || size(ranges, 2) ~= 2
    error("makeWindowIndex_:BadRange", ...
        "%s ranges must be an n x 2 numeric matrix.", axisName);
end

ranges = sort(double(ranges), 2);
wins = cell(size(ranges, 1), 1);

for i = 1:size(ranges, 1)
    idx = find(axisVec >= ranges(i, 1) & axisVec <= ranges(i, 2));

    if isempty(idx)
        error("makeWindowIndex_:EmptyWindow", ...
            "No %s sample falls within [%g, %g].", ...
            axisName, ranges(i, 1), ranges(i, 2));
    end

    wins{i} = idx(:).';
end
end

%% ========================================================================
function out = averageMap_(G, freqWins, timeWins)
% Average chancmb x freq x time map into chancmb x fwin x twin.

nCmb = size(G, 1);
nFWin = numel(freqWins);
nTWin = numel(timeWins);

out = zeros(nCmb, nFWin, nTWin, "like", G);

for iF = 1:nFWin
    fIdx = freqWins{iF};

    for iT = 1:nTWin
        tIdx = timeWins{iT};

        tmp = G(:, fIdx, tIdx);
        tmp = reshape(tmp, nCmb, []);

        out(:, iF, iT) = mean(tmp, 2, "omitnan");
    end
end
end