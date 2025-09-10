function success = save(FILENAME, varargin)
%SAVE  Save variables to file only if file does not exist.
%
% SYNTAX:
%   success = saveIfNotExist(FILENAME, var1, var2, ..., Name, Value)
%
% INPUTS:
%     FILENAME  - target .mat file
%     varargin  - variable names (string/char) from caller workspace, optionally
%                 followed by MATLAB save Name/Value pairs
%
% EXAMPLES:
%   x = 1; y = 2;
%   mu.save('test.mat', 'x', 'y', '-v7.3');

success = false;

% Separate variable names and name-value options
isOption = cellfun(@(x) ischar(x) && strncmp(x, '-', 1), varargin);
varNames = varargin(~isOption);
options  = varargin(isOption);

% Collect variable values from caller workspace
varStruct = struct();
for k = 1:numel(varNames)
    varName = varNames{k};
    if evalin('caller', sprintf('exist(''%s'', ''var'')', varName))
        varStruct.(varName) = evalin('caller', varName);
    else
        warning('Variable "%s" does not exist in caller workspace. Skipped.', varName);
    end
end

% Check if file exists
if ~isfile(FILENAME)
    save(FILENAME, '-struct', 'varStruct', options{:});
    success = true;
else
    fprintf('%s already exists. Skip saving.\n', FILENAME);
end

end
