function res = getVarsFromWorkspace(varargin)
%GETVARSFROMWORKSPACE  Search variables in caller workspace matching regex patterns.
%
% SYNTAX:
%   res = mu.getVarsFromWorkspace(pattern1, pattern2, ...)
%
% INPUTS:
%     regexps  - 0 or more regexp pattern strings (char or string)
%
% OUTPUTS:
%     res  - struct with fields named by matched variables and values from caller workspace
%
% EXAMPLE:
%   vars = fieldnames(mu.getVarsFromWorkspace('^result_', '^output_'));
%   save('data.mat', vars{:});

% return all variables for empty input
if nargin == 0
    varNames = evalin('caller', 'who;');
else
    % validate inputs
    for k = 1:nargin
        if ~(ischar(varargin{k}) || isStringScalar(varargin{k}))
            error('All inputs must be character vectors or string scalars.');
        end
        if strlength(varargin{k}) == 0
            error('Empty regexp pattern is not allowed.');
        end
    end

    % use joint regexp
    combinedRegexp = strjoin(cellfun(@char, varargin, 'UniformOutput', false), '|');
    varNames = evalin('caller', ['who(''-regexp'', ''', combinedRegexp, ''');']);
end

if isempty(varNames)
    % not found
    res = struct();
    warning('No variables matching given pattern(s) found in workspace.');
    return;
end

varsExpr = strcat("struct(", strjoin(cellfun(@(v) ['''' v ''', evalin(''caller'', ''' v ''')'], varNames, 'UniformOutput', false), ', '), ")");
res = evalin("caller", varsExpr);

return;
end
