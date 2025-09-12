function fcn = path2func(P)
%PATH2FUNC  Get function handle from full path or name of an M-file.
%   FCN = mu.path2func(P) returns a function handle given the full path
%   of an .m file or the name of a built-in function.

arguments
    P {mustBeFile}
end

% Convert to absolute path
P = mu.getabspath(P);

[folder, name, ext] = fileparts(P);
if ~strcmpi(ext, '.m')
    error("path2func:NotMFile", ...
        "Input should be the full path of a .m file.");
end

% Check if under +package folder
parts = strsplit(folder, filesep);
pkgIdx = find(startsWith(parts, '+'), 1, 'first');

if ~isempty(pkgIdx)
    % Get package name
    pkgParts = cellfun(@(x) x(2:end), parts(pkgIdx:end), 'UniformOutput', false);
    funcName = strjoin([pkgParts, {name}], '.');
    addFolder = strjoin(parts(1:pkgIdx-1), filesep);
else
    funcName = name;
    addFolder = folder;
end

% add to path
if ~isempty(addFolder) && ~contains(path, addFolder)
    addpath(addFolder);
    % remove path at the end of this function
    cleanupObj = onCleanup(@() rmpath(addFolder));
end

% Create function handle
fcn = str2func(funcName);

return;
end
