function [peakIdx, troughIdx] = findpeaktrough(data, dim)
% FINDPEAKTROUGH - Find logical indices of peaks and troughs in signals
% INPUT:
%   data - [nsample, nch] or [nch, nsample]
%   dim  - Dimension along which to find peaks/troughs (default: 2)
% OUTPUT:
%   peakIdx, troughIdx - logical matrix same size as data

if nargin < 2, dim = 2; end
validateattributes(data, {'numeric'}, {'2d'});
assert(ismember(dim, [1, 2]), 'dim must be 1 or 2.');

% Bring target dimension to columns
if dim == 1
    data = data.';
end
[nch, nsample] = size(data);

% Preallocate
peakIdx   = false(nch, nsample);
troughIdx = false(nch, nsample);

% First derivative
d1 = diff(data, 1, 2);
% Sign of derivative
s1 = sign(d1);
% Second derivative sign changes
s2 = diff(s1, 1, 2);

% Peaks: slope changes from + to -
peakIdx(:, 2:end-1) = (s2 == -2);
% Troughs: slope changes from - to +
troughIdx(:, 2:end-1) = (s2 == 2);

% Handle flat regions (equal consecutive values)
flatMask = (d1 == 0);
for ch = 1:nch
    eqStarts = find(diff([false, flatMask(ch,:), false]) == 1);
    eqEnds   = find(diff([flatMask(ch,:), false]) == -1);
    for k = 1:numel(eqStarts)
        st = eqStarts(k);
        en = eqEnds(k);
        if (st == 1 || data(ch, st-1) < data(ch, st)) && ...
                (en == nsample || data(ch, en+1) < data(ch, en))
            peakIdx(ch, st) = true;
        elseif (st == 1 || data(ch, st-1) > data(ch, st)) && ...
                (en == nsample || data(ch, en+1) > data(ch, en))
            troughIdx(ch, st) = true;
        end
    end
end

% Restore original orientation
if dim == 1
    peakIdx   = peakIdx.';
    troughIdx = troughIdx.';
end

return;
end
