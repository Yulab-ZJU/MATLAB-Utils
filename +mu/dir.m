function [res, resCell] = dir(name)
%DIR  List files and return their full paths.
%
% SYNTAX:
%   res = mu.dir(name)
%   [res, resCell] = mu.dir(name)
%
% INPUT:
%   name      - File name, folder path, wildcard expression, or recursive
%               wildcard expression accepted by MATLAB's DIR function.
%
% OUTPUT:
%   res       - Structure array returned by MATLAB's built-in DIR function.
%   resCell   - Cell array of character vectors containing the full paths
%               corresponding to entries in res.
%
% EXAMPLES:
%   [res, paths] = mu.dir('D:\Data\*.mat');
%   [res, paths] = mu.dir('D:\Data\**\*.mat');

arguments
    name (1, 1) string
end

% Call MATLAB's DIR rather than mu.dir to avoid recursive invocation.
res = builtin('dir', name);

if isempty(res)
    resCell = cell(0, 1);
    return;
end

% Preserve the shape of the structure array returned by DIR.
resCell = arrayfun( ...
    @(x) fullfile(x.folder, x.name), ...
    res, ...
    'UniformOutput', false ...
    );

return;
end