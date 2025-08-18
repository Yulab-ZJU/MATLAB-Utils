function trialsData = mu_selectWave(data, fs, segTime, window, scaleFactor)
% Segment multi-channel time-series data (e.g., LFP/ECoG/EEG)
%
% Inputs:
%   data      : [nch × ntime] double
%   fs        : Sampling frequency (Hz)
%   segTime   : [ntrial × 1] event times (ms)
%   window    : [preEvent, postEvent] (ms)
%   scaleFactor: optional scaling (default = 1)
% Output:
%   trialsData: {ntrial × 1} cell array, each [nch × winLength]

narginchk(4, 5);
if nargin < 5
    scaleFactor = 1;
end

% Convert ms -> samples
windowSamples = round(window / 1e3 * fs);   % [pre, post]
segSamples    = round(segTime(:) / 1e3 * fs); 

% Dimensions
[nch, ntime] = size(data);
ntrial    = numel(segSamples);
winLength = diff(windowSamples) + 1;

% Preallocate cell array
trialsData = cell(ntrial, 1);

% Flag for warning
warned = false;

% Loop over trials
for k = 1:ntrial
    startIdx = segSamples(k) + windowSamples(1);
    stopIdx  = startIdx + winLength - 1;

    % Boundary check
    if startIdx < 1 || stopIdx > ntime
        if ~warned
            warning('Some trials exceed data bounds; out-of-range samples filled with NaN.');
            warned = true;
        end
        tmp = nan(nch, winLength, 'like', data);
        validRange = max(1, startIdx):min(ntime, stopIdx);
        tmp(:, validRange - startIdx + 1) = data(:, validRange);
    else
        tmp = data(:, startIdx:stopIdx);
    end

    trialsData{k} = tmp * scaleFactor;
end

return;
end
