function res = getVarsFromWorkspace(varargin)
% GETVARSFROMWORKSPACE Search variables in caller workspace matching regex patterns
%
% Usage:
%   res = mu.getVarsFromWorkspace(pattern1, pattern2, ...)
%
% Input:
%   varargin - 0 or more regexp pattern strings (char or string)
%
% Output:
%   res - struct with fields named by matched variables and values from caller workspace
%
% Example:
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

% 使用一次性evalin获取所有变量，避免循环evalin性能瓶颈
% 拼接成结构体构造字符串，如: 'struct(''var1'', val1, ''var2'', val2, ...)'
varsExpr = strcat("struct(", strjoin(cellfun(@(v) ['''' v ''', evalin(''caller'', ''' v ''')'], varNames, 'UniformOutput', false), ', '), ")");
res = evalin("caller", varsExpr);

return;
end
