function trialsData = mu_selectWave(data, fs, segTime, window)
% Epoching time-series data (vectorized, safe for logical mask indexing)
%
% Inputs:
%   data      : [nch x ntime] input signal
%   fs        : Sampling frequency (Hz)
%   segTime   : Segmentation time points (ms)
%   window    : [preEvent, postEvent] window around segTime (ms)
% Output:
%   trialsData: {ntrial x 1} cell array of extracted windows

% Convert time values to sample points
windowSamples = round(window / 1e3 * fs);  % [pre, post] in samples
segSamples    = round(segTime(:) / 1e3 * fs); % Ensure column vector

% Dimensions
nch       = size(data, 1);
ntrial    = numel(segSamples);
winLength = diff(windowSamples) + 1;

% Calculate sample indices for all trials
allStarts     = segSamples + windowSamples(1);
sampleIndices = allStarts + (0:winLength - 1); % [ntrial × winLength]

% Identify valid samples
validMask = sampleIndices >= 1 & sampleIndices <= size(data, 2);
if any(~validMask(:, 1)) || any(~validMask(:, end))
    warning('Window exceeds data bounds for some segments');
end

% Preallocate output
trialsData = nan(nch, winLength, ntrial, 'like', data);

% ===== Vectorized fill =====
% Expand channel/trial/sample into vectors
[trialIdx, sampleIdx] = find(validMask); % only valid positions
chanIdx  = repelem((1:nch).', numel(trialIdx)); % repeat for all channels

% Map to data indices
srcIdx   = sampleIndices(sub2ind(size(sampleIndices), trialIdx, sampleIdx));
srcIdx   = repmat(srcIdx, nch, 1);

% Destination indices in trialsData
dstIdx = sub2ind(size(trialsData), ...
                 chanIdx, ...
                 repmat(sampleIdx, nch, 1), ...
                 repmat(trialIdx, nch, 1));

% Assign in one shot
trialsData(dstIdx) = data(sub2ind(size(data), chanIdx, srcIdx));

% Convert to cell array [ntrial × 1]
trialsData = squeeze(mat2cell(trialsData, nch, winLength, ones(ntrial, 1)));

return;
end
