function counts = histcounts(data, edges, binSize)
% HISTCOUNTS Count number of data points in bins centered at edges with given bin size
%
% counts = mu.histcounts(data, edges, binSize)
%
% This function mimics the behavior of binning data into intervals centered
% at 'edges' with a width of 'binSize'. It uses MATLAB's built-in histcounts
% for better performance.
%
% Each bin is: [edges(i) - binSize/2, edges(i) + binSize/2)

if isempty(data)
    counts = zeros(length(edges), 1);
    return;
end

if ~isvector(data) || ~isreal(data)
    error("data should be a real vector");
end

% Construct bin edges for histcounts
binLeftEdges = edges(:) - binSize/2;
binRightEdges = edges(:) + binSize/2;

% Ensure no overlap / ordering
binEdges = [binLeftEdges, binRightEdges]';

% Use discretize to find which bin each value falls into
% Convert bin edges to full list of edges
edgesHist = reshape(binEdges, 1, []);  % Interleaved edges
edgesHist = sort(edgesHist);           % Ensure strictly increasing

% Use histcounts with precomputed bin edges
countsAll = histcounts(data, edgesHist);

% Only odd-indexed bins count (our bins are [left, right), and every second one is valid)
counts = countsAll(1:2:end)';

return;
end
