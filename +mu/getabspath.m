function P = getabspath(relativePath)
% GETABSPATH  Convert relative path to absolute path without creating folders.
%   P = mu.getabspath(relativePath) returns the absolute path corresponding to
%   the input relativePath. Does NOT create any folder.
%
% NOTES:
%   If relativePath is empty, reports an error.

arguments
    relativePath {mustBeTextScalarOrEmpty} = ""
end

if nargin < 1 || isempty(relativePath)
    P = pwd;
    return;
end

relativePath = char(relativePath); % ensure char array

% If the input is already an absolute path, just normalize it and return
if isAbsolutePath(relativePath)
    P = normalizePath(relativePath);
    return;
end

% Input is a relative path or single file/folder name
% Combine with current folder to get full path
P = fullfile(pwd, relativePath);
P = normalizePath(P);

return;
end

%% 
function tf = isAbsolutePath(pathStr)
    if ispc % Windows
        tf = ~isempty(regexp(pathStr, '^[A-Za-z]:\\', 'once')) || startsWith(pathStr, '\\');
    else % Unix
        tf = startsWith(pathStr, '/');
    end
end

function p = normalizePath(pathStr)
    p = char(java.io.File(pathStr).getCanonicalPath());
end

function mustBeTextScalarOrEmpty(x)
    if ~(isempty(x) || isstring(x) && isscalar(x) || ischar(x) && isrow(x))
        error('relativePath must be a char, string scalar, or empty.');
    end
end
