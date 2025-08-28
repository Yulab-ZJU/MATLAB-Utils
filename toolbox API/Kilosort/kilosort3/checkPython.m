function checkPython()
%CHECKPYTHON Checks and sets the Python version in the system PATH for Kilosort 3 compatibility.
%
% This function scans all Python paths in the system PATH environment variable,
% detects their versions, and ensures that Python 3.7 is used (required by Kilosort 3).
% If the default Python version is not 3.7, it attempts to switch the PATH to use Python 3.7.
% If no compatible version is found, it throws an error.
%
% Usage:
%   checkPython()
%
% Requirements:
%   - Kilosort 3 requires Python 3.7.
%   - The function modifies the PATH environment variable if needed.

paths = getenv("Path");
pyPaths = split(paths, ";");
pyPaths = pyPaths(contains(pyPaths, "Python", "IgnoreCase", true));
pyPaths = pyPaths(logical(cellfun(@(x) exist(fullfile(x, "python.exe"), "file"), pyPaths)));

% delete '\' at the end of the path
for index = 1:length(pyPaths)
    if endsWith(pyPaths{index}, '\')
        pyPaths{index} = pyPaths{index}(1:end - 1);
    end
end

% find python versions (3.x)
[mainvers, subvers] = deal(zeros(length(pyPaths), 1));
for index = 1:length(pyPaths)
    str = strcat(fullfile(pyPaths{index}, "python.exe"), " --version");
    [~, ver] = system(str);
    ver = strrep(ver, 'Python ', '');
    ver = split(ver, '.');
    mainvers(index) = str2double(ver{1});
    subvers(index) = str2double(ver{2});
end

if mainvers(1) < 3 || (mainvers(1) == 3 && subvers(1) > 7)
    warning(['Unsupported python version for kilosort 3 ' ...
             '(current python version is ', ...
             num2str(mainvers(1)), '.', num2str(subvers(1)), '.x).']);

    if any(mainvers == 3 & subvers == 7)
        warning('Use python 3.7 instead.');
        for index = 1:length(pyPaths)
            paths = strrep(paths, [pyPaths{index}, '\;'], '');
            paths = strrep(paths, [pyPaths{index}, ';'], '');
            paths = strrep(paths, [pyPaths{index}, '\Scripts\;'], '');
            paths = strrep(paths, [pyPaths{index}, '\Scripts;'], '');
        end
        paths = [pyPaths{find(mainvers == 3 & subvers == 7, 1)}, ';', ...
                 pyPaths{find(mainvers == 3 & subvers == 7, 1)}, '\Scripts;', ...
                 paths];
        setenv("Path", paths);
    else
        error('No compatible python version found.');
    end

end