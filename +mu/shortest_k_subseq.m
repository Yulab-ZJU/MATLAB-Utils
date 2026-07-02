function [S, info] = shortest_k_subseq(A, k, opts)
%SHORTEST_K_SUBSEQ  Linear De Bruijn sequence with optional random traversal.
%
%   S = mu.shortest_k_subseq(A, k)
%   [S, info] = mu.shortest_k_subseq(A, k, opts)
%
% Generates a shortest linear sequence over the unique symbol alphabet A
% that contains every length-k word exactly once as a contiguous window.
% The output length is numel(A)^k + k - 1.
%
% opts fields
% -----------
%   randomizeEdges      : Randomly permute the outgoing edges at each
%                         De Bruijn-graph node before Hierholzer traversal.
%                         Default = false.
%   randomizeStartNode  : Randomly choose the Eulerian-cycle start node.
%                         This mainly changes the linearization/rotation.
%                         Default = false.
%   rngSeed             : Optional nonnegative integer seed. Default = [].
%   restoreRng          : Restore MATLAB global RNG state after generation.
%                         Default = true.
%   verify              : Verify exact order-k coverage. Default = false.
%
% Notes
% -----
% randomizeEdges=true creates distinct Eulerian traversals while preserving
% exact order-k coverage. This is the key option used to create multiple
% large-context carriers S1, S2, ... for the PTS experiment.

arguments
    A {mustBeNumeric, mustBeReal, mustBeVector, mustBeFinite}
    k (1,1) double {mustBeInteger, mustBePositive}
    opts.randomizeEdges (1,1) logical = false
    opts.randomizeStartNode (1,1) logical = false
    opts.rngSeed = []
    opts.restoreRng (1,1) logical = true
    opts.verify (1,1) logical = false
end

A = A(:).';
n = numel(A);

if n == 0
    S = A;
    info = struct('nAlphabet', 0, 'k', k, 'indexCycle', [], ...
        'indexLinear', [], 'options', opts);
    return;
end

if numel(unique(A)) ~= n
    error('mu:shortest_k_subseq:DuplicateAlphabet', ...
        'A must contain unique symbol values.');
end

if ~isempty(opts.rngSeed)
    validateattributes(opts.rngSeed, {'numeric'}, ...
        {'scalar', 'real', 'finite', 'nonnegative', 'integer'}, ...
        mfilename, 'opts.rngSeed');

    previousRng = rng;

    if opts.restoreRng
        cleanupObj = onCleanup(@() rng(previousRng));
    end

    rng(double(opts.rngSeed), 'twister');
end

if k == 1
    idxCycle = 0:(n - 1);

    if opts.randomizeEdges
        idxCycle = idxCycle(randperm(n));
    end
else
    idxCycle = localDeBruijnIndexGraph(n, k, ...
        opts.randomizeEdges, opts.randomizeStartNode);
end

idxLinear = [idxCycle, idxCycle(1:(k - 1))];
S = A(idxLinear + 1);

if opts.verify
    localVerifyExactCoverage(idxLinear, n, k);
end

info = struct;
info.nAlphabet = n;
info.k = k;
info.indexCycle = idxCycle;
info.indexLinear = idxLinear;
info.options = opts;

end


function idxCycle = localDeBruijnIndexGraph(n, k, randomizeEdges, randomizeStartNode)
%LOCALDEBRUIJNINDEXGRAPH  Randomizable Eulerian traversal of De Bruijn graph.

numNodes = n^(k - 1);

% edgeOrder(v, :) gives the order in which outgoing symbols are traversed
% from node v. Each row remains a permutation of 0:(n-1), so every edge is
% still used exactly once.
edgeOrder = repmat(0:(n - 1), numNodes, 1);

if randomizeEdges
    for nodeIndex = 1:numNodes
        edgeOrder(nodeIndex, :) = randperm(n) - 1;
    end
end

if randomizeStartNode
    startNode = randi(numNodes) - 1;
else
    startNode = 0;
end

nextEdge = ones(numNodes, 1);

% Preallocate to the exact number of graph edges.
nEdge = n^k;
stackNodes = zeros(1, nEdge + 1);
stackLabels = zeros(1, nEdge);
result = zeros(1, nEdge);

nodeTop = 1;
labelTop = 0;
resultCount = 0;
stackNodes(nodeTop) = startNode;

while nodeTop > 0
    v = stackNodes(nodeTop);
    edgeIndex = nextEdge(v + 1);

    if edgeIndex <= n
        x = edgeOrder(v + 1, edgeIndex);
        nextEdge(v + 1) = edgeIndex + 1;

        w = mod(v * n + x, numNodes);

        nodeTop = nodeTop + 1;
        stackNodes(nodeTop) = w;

        labelTop = labelTop + 1;
        stackLabels(labelTop) = x;
    else
        nodeTop = nodeTop - 1;

        if labelTop > 0
            resultCount = resultCount + 1;
            result(resultCount) = stackLabels(labelTop);
            labelTop = labelTop - 1;
        end
    end
end

if resultCount ~= nEdge
    error('mu:shortest_k_subseq:TraversalFailure', ...
        'Eulerian traversal returned %d labels, expected %d.', ...
        resultCount, nEdge);
end

idxCycle = fliplr(result);

end


function localVerifyExactCoverage(idxLinear, n, k)
%LOCALVERIFYEXACTCOVERAGE  Check that all order-k words occur once.

nWord = n^k;
startIndex = (1:nWord).';
wordIndex = startIndex + (0:(k - 1));
word = idxLinear(wordIndex);

[~, ~, groupIndex] = unique(word, 'rows');

if numel(unique(groupIndex)) ~= nWord
    error('mu:shortest_k_subseq:CoverageFailure', ...
        'The generated sequence does not contain all order-%d words once.', k);
end

end
