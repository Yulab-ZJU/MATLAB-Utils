function counts = histcounts(data, edges, binSize)
%HISTCOUNTS  Count number of data points in bins centered at edges with given bin size.
%
% counts = mu.histcounts(data, edges, binSize)
%
% Each bin is treated as [edges(i) - binSize/2, edges(i) + binSize/2).
% Overlapping bins are allowed — a data point may be counted in multiple bins.
%
% This implementation is efficient: it uses a single histcounts call on the
% union of all boundaries and then sums subintervals for each bin.

% Input validation
if nargin < 3
    error('Requires data, edges, and binSize');
end
if isempty(data)
    counts = zeros(numel(edges), 1);
    return;
end
if ~isvector(data) || ~isreal(data)
    error('data should be a real vector');
end
if ~isvector(edges) || ~isreal(edges)
    error('edges should be a real vector');
end
if ~isscalar(binSize) || ~isreal(binSize) || binSize <= 0
    error('binSize must be a positive scalar');
end

% Ensure column vectors
data = data(:);
edges = edges(:);
m = numel(edges);

% Build left and right boundaries
leftEdges  = edges - binSize/2;
rightEdges = edges + binSize/2;

% Combine boundaries and get unique sorted values with index mapping
combined = [leftEdges; rightEdges];    % 2m x 1
[allEdges, ~, ic] = unique(combined); % allEdges sorted, ic maps combined->allEdges index

% If there are fewer than 2 unique boundaries, no intervals exist
if numel(allEdges) < 2
    counts = zeros(m,1);
    return;
end

% Fast histogram over the fine-grained partition defined by allEdges
countsSeg = histcounts(data, allEdges); % length = numel(allEdges)-1

% Map left/right to indices in the 'allEdges' grid
leftIdx  = ic(1:m);
rightIdx = ic(m+1:2*m);

% Build prefix sums for fast interval sum: cumsumSeg(k) = sum(countsSeg(1:k-1))
cumsumSeg = [0, cumsum(countsSeg)]; % length = numel(allEdges)

% For bin i, sum countsSeg(leftIdx(i) : rightIdx(i)-1) = cumsumSeg(rightIdx(i)) - cumsumSeg(leftIdx(i))
% If rightIdx == leftIdx then sum is 0
counts = cumsumSeg(rightIdx) - cumsumSeg(leftIdx);

% Ensure column vector and integer type
counts = counts(:);

return;
end
