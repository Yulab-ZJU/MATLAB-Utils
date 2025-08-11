function ROOTPATH = getrootpath(P, N)
% GETROOTPATH Return the root path N levels up from path P
%
%   ROOTPATH = mu.getrootpath(P, N)
%
% Inputs:
%   P      - input path (file or folder), char or string scalar
%   N      - positive integer, how many folder levels to go up
%
% Output:
%   ROOTPATH - root path N levels above P

arguments
    P {mustBeTextScalar}
    N (1,1) {mustBePositive, mustBeInteger}
end

% Get absolute path
P = mu.getabspath(P);
if ~isfolder(P)
    P = fileparts(P);
end

% Divide
parts = split(P, filesep);

if isempty(parts{1})
    parts{1} = filesep; % unix root
end

if N >= numel(parts)
    error('Cannot go up %d levels from path %s (only %d levels available).', N, P, numel(parts));
end

rootParts = parts(1:end - N);

if ispc || ~strcmp(rootParts{1}, filesep) % Windows
    ROOTPATH = fullfile(rootParts{:});
else % Unix
    ROOTPATH = fullfile(filesep, fullfile(rootParts{2:end}));
end

return;
end