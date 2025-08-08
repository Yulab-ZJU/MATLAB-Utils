function trialsData = selectWave(data, fs, segTime, window)
% SELECTWAVE - Epoching time-series data
% Inputs:
%   data      : [nChannels x nSamples] input signal
%   fs        : Sampling frequency (Hz)
%   segTime   : Segmentation time points (ms)
%   window    : [preEvent, postEvent] window around segTime (ms)
% Output:
%   trialsData: {nTrials x 1} cell array of extracted windows

% Convert time values to sample points (round for nearest sample)
windowSamples = round(window / 1e3 * fs);  % [pre, post] in samples
segSamples = round(segTime(:) / 1e3 * fs); % Ensure column vector

% Get dimensions
nChannels = size(data, 1);
winLength = diff(windowSamples) + 1;      % Window length in samples
nTrials = length(segSamples);

% Calculate all window ranges simultaneously
allStarts = segSamples + windowSamples(1); % [nTrials x 1] start indices

% Create full index matrix [nTrials x winLength]
% Each row contains sample indices for one trial
sampleIndices = allStarts + (0:winLength - 1);

% Identify valid (in-bounds) samples
validMask = sampleIndices >= 1 & sampleIndices <= size(data, 2);

% Warning for out-of-bounds windows
if any(~validMask(:, 1)) || any(~validMask(:, end))
    warning('Window exceeds data bounds for some segments');
end

% Preallocate 3D array [nChannels x winLength x nTrials]
trialsData = nan(nChannels, winLength, nTrials, 'like', data);

% Vectorized data extraction (only loop over channels for memory efficiency)
for ch = 1:nChannels
    % Get all valid samples for current channel in one operation
    validIdx = sampleIndices(validMask);
    trialsData(ch, validMask') = data(ch, validIdx);
end

% Convert 3D array to cell array (matches original output format)
trialsData = squeeze(mat2cell(trialsData, nChannels, winLength, ones(nTrials, 1)));

return;
end