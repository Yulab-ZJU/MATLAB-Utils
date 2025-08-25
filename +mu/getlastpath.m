function [res, folderNames, path_Nth] = getlastpath(P, N)
% GETLASTPATH  Get last N folder levels from path P
%
%   [res, folderNames, path_Nth] = mu.getlastpath(P, N)
%
% Inputs:
%   P - input path string (file or folder), char or string
%   N - positive integer number of folder levels to extract from the end
%
% Outputs:
%   res         - reconstructed path string with last N folders (fullfile format)
%   folderNames - cell array of folder names (from higher to lower level)
%   path_Nth    - last N-th folder name (highest in the extracted segment)

arguments
    P {mustBeTextScalar}  % char or string scalar
    N (1,1) {mustBePositive, mustBeInteger}
end

% Get absolute path
P = mu.getabspath(P);
[~, ~, ext] = fileparts(P);
if ~isempty(ext)
    P = fileparts(P);
end

% Divide
parts = strsplit(P, filesep);

if isempty(parts{1})
    parts{1} = filesep; % unix root
end

nParts = numel(parts);

if N > nParts
    warning('Requested N=%d is larger than number of path parts (%d). Returning full path.', N, nParts);
    N = nParts;
end

folderNames = parts(end - N + 1:end);
res = fullfile(folderNames{:});
path_Nth = folderNames{1};

return;
end
