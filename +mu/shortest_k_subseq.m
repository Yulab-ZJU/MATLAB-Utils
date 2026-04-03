function S = shortest_k_subseq(A, k)
%SHORTEST_K_SUBSEQ  Shortest 1D sequence containing all k-length words.
%
%   S = mu.shortest_k_subseq(A, k)
%
% INPUT
%   A : 1×n or n×1 vector of symbols (numeric/char/anything indexable)
%   k : positive integer, subsequence length
%
% OUTPUT
%   S : 1×(n^k + k - 1) sequence over A, where every consecutive
%       window of length k is unique and all possible k-length
%       sequences over A appear exactly once.
%
% EXAMPLE
%   A = [1 2 3];
%   k = 2;
%   
%   % S contains all pairs [1 1], [1 2], ..., [3 3] as contiguous subsequences.
%   S = mu.shortest_k_subseq(A, k)
%   
%   % Randomized sequence S
%   S2 = mu.shortest_k_subseq(A(randperm(numel(A))), k)

A = A(:).';        % force row vector
n = numel(A);
validateattributes(k, 'numeric', {'positive', 'integer', 'scalar'});

if n == 0
    S = [];
    return;
end
if k == 1
    % trivial case: just list all symbols once
    S = A;
    return;
end

% Step 1: generate De Bruijn sequence indices on alphabet {0,...,n-1}
idx_cycle = debruijn_index_graph(n, k);   % length n^k, 0-based

% Step 2: make linear sequence by appending first (k-1) indices
idx_linear = [idx_cycle, idx_cycle(1:k-1)];

% Step 3: map indices back to user symbols in A (MATLAB is 1-based)
S = A(idx_linear + 1);
end

function idx_cycle = debruijn_index_graph(n, k)
%DEBRUIJN_INDEX_GRAPH  De Bruijn sequence over {0,...,n-1} of order k.
%
%   idx_cycle = debruijn_index_graph(n, k)
%
% OUTPUT
%   idx_cycle : row vector of length n^k, with entries in 0:(n-1)
%               forming a cyclic De Bruijn sequence.
%
% METHOD
%   Construct the De Bruijn graph whose nodes are (k-1)-tuples over
%   the alphabet {0,...,n-1}, edges correspond to k-tuples (shift
%   left and append new symbol), then find an Eulerian cycle using
%   Hierholzer's algorithm and read off the edge labels.

if k == 1
    idx_cycle = 0:(n-1);
    return;
end

numNodes = n^(k - 1);        % number of (k-1)-tuples
outEdgeNext = ones(numNodes, 1);  % next outgoing label index (1..n+1)

stackNodes  = 0;   % current path of nodes (0-based)
stackLabels = [];  % labels along the path (0..n-1)
res         = [];  % collected edge labels in reverse order

while ~isempty(stackNodes)
    v  = stackNodes(end);        % current node index 0..numNodes-1
    ei = outEdgeNext(v + 1);     % which outgoing edge to use next (1..n+1)

    if ei <= n
        % still have unused outgoing edges from v
        x = ei - 1;              % edge label in 0..n-1
        outEdgeNext(v + 1) = ei + 1;

        % next node: shift left and append x (in base-n)
        w = mod(v * n + x, numNodes);

        % extend current path
        stackNodes(end + 1)  = w;
        stackLabels(end + 1) = x;
    else
        % no more outgoing edges, backtrack
        stackNodes(end) = [];
        if ~isempty(stackLabels)
            % when backtracking, record the edge label
            res(end + 1)   = stackLabels(end);
            stackLabels(end) = [];
        end
    end
end

% res is in reverse Eulerian order
idx_cycle = fliplr(res);

return;
end

