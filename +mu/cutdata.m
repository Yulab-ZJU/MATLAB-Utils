function [trialsData, window] = cutdata(trialsData, windowOld, windowNew)
% CUTDATA Extracts a time window from trial data.
%
% This function trims trial data to a specified new time window, given the original time window.
% Both time windows are specified in milliseconds. The function supports both single-trial
% (double matrix) and multi-trial (cell array) input formats.
%
% INPUTS:
%   trialsData  - Trial data, either a [nChannels x nSamples] double matrix or a cell array of such matrices
%   windowOld   - Original time window [start, end] in ms
%   windowNew   - Desired time window [start, end] in ms
%
% OUTPUTS:
%   trialsData  - Data cut to the new time window, same format as input
%   window      - Actual time window used after cutting [start, end] in ms
%
% NOTES:
%   - If the new window exceeds the original window, it will be limited to the original range.
%   - For cell arrays, empty cells are ignored.
%
% Example:
%   [dataCut, win] = cutdata(data, [-200, 800], [0, 500]);

if windowNew(2) > windowOld(2)
    warning('New time window exceeds data range. Limit to upper range.');
    windowNew(2) = windowOld(2);
end

if isa(trialsData, "double") % For single trial input
    t = linspace(windowOld(1), windowOld(2), size(trialsData, 2));
    tIdx = find(t >= windowNew(1), 1):find(t >= windowNew(2), 1);
    trialsData = trialsData(:, tIdx);
elseif isa(trialsData, "cell")
    idx = find(~cellfun(@isempty, trialsData));
    t = linspace(windowOld(1), windowOld(2), size(trialsData{idx(1)}, 2));
    tIdx = find(t >= windowNew(1), 1):find(t >= windowNew(2), 1);
    trialsData(idx) = cellfun(@(x) x(:, tIdx), trialsData(idx), "UniformOutput", false);
else
    error("Invalid data type");
end

window = [t(tIdx(1)), t(tIdx(end))];

return;
end