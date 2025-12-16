function [status, cmdout] = mu_pydebug_pycharm(pyscriptPATH, pyexePATH, varargin)
%MU_PYDEBUG_PYCHARM  Run python script via MATLAB and debug in PyCharm (via debug server).
%
% INPUTS:
%   REQUIRED:
%     pyscriptPATH  - Full path of python script to run
%     pyexePATH     - Full path of python exe
%                     Must be same as your PyCharm setting
%
%   POSITIONAL (optional, forwarded to python as positional args):
%     req1, req2, ... - Required/positional args for python script, e.g.
%                       mu_pydebug_pycharm('md2word.py', pyexe, "equations.md", "equations.docx", ...)
%
%   NAMEVALUE:
%     Port          - Port number of debug server (default=5678)
%     Other name-value inputs for python script (forwarded as --key value)
%
% OUTPUTS:
%     status        - 0: success, other values: failed
%     cmdout        - Output information from command line
%
% NOTES:
%   1. Install pydevd-pycharm in your python environment (in conda env or base):
%      `pip install pydevd-pycharm` (or with a specific version)
%   2. Settings in PyCharm:
%      - Make sure that PyCharm uses the same python version as pyexePATH specifies.
%      - Build a python debug server in PyCharm (if not existed):
%        ----------------------------------------------------------------
%        Run -> Edit Configurations -> +(Left-top) -> Python Debug Server
%        ----------------------------------------------------------------
%        Port: 5678 (or other port you want, consistent with 'Port' here)
%      - Set break points in PyCharm.
%      - Start debug server in PyCharm.
%
%   - To force positional parsing stop explicitly, you can insert a marker "--":
%       mu_pydebug_pycharm(..., "requiredParam1", "requiredParam2", "--", "Port", 5678, "param3", val3)
%
% Usage:
%   1. Start debug server in PyCharm (see NOTES point 2).
%   2. Run MATLAB code:
%      mu_pydebug_pycharm('~\yourscript.py', ...
%                         'C:\Users\YOU\.conda\envs\demo_env\python.exe', ...
%                         'requiredParam1', 'requiredParams', ...
%                         'param1', val1, 'param2', val2)

% ------------------------------------------------------------
% Pre-split varargin into:
%   (1) python positional args: pyPosArgs
%   (2) name-value args for MATLAB parser: nvArgs
% Heuristic:
%   - stop when hitting MATLAB key (Port), OR
%   - stop when hitting a likely name-value "key" (isvarname && has following value), OR
%   - allow explicit stop marker "--"
% ------------------------------------------------------------
matlabKeys = "Port";
pyPosArgs = strings(1,0);

k = 1;
while k <= numel(varargin)
    a = varargin{k};

    % explicit marker: stop positional parsing
    if (ischar(a) || isstring(a)) && isscalar(string(a)) && string(a) == "--"
        k = k + 1;
        break;
    end

    % determine whether current token looks like a name-value key
    isText = (ischar(a) || isstring(a)) && isscalar(string(a));
    if isText
        aStr = string(a);

        % if MATLAB parameter names encountered, stop
        if any(strcmpi(aStr, matlabKeys))
            break;
        end

        % if it looks like a "key" in name-value pairs, stop
        % (this keeps compatibility with existing 'param', val style)
        if k < numel(varargin)
            if isvarname(char(aStr))
                break;
            end
        end
    end

    % otherwise treat as python positional arg
    pyPosArgs(end+1) = string(a);
    k = k + 1;
end

nvArgs = varargin(k:end);

% Parse inputs
mIp = inputParser;
mIp.KeepUnmatched = true;
mIp.addRequired("pyscriptPATH", @mu.isTextScalar);
mIp.addRequired("pyexePATH", @mu.isTextScalar);
mIp.addParameter("Port", 5678, @(x) validateattributes(x, 'numeric', {'scalar', 'positive', 'integer'}));
mIp.parse(pyscriptPATH, pyexePATH, nvArgs{:});
port = mIp.Results.Port;

% Environment variables
setenv("PYCHARM_HOST","localhost");
setenv("PYCHARM_PORT", num2str(port));
setenv("PYCHARM_SUSPEND","1");

% launcher
launcher = fullfile(fileparts(mfilename('fullpath')), 'private', 'launcher_pycharm.py');
if ~exist(launcher, "file")
    error('mu_pydebug_pycharm:MissingLauncher', 'launcher_pycharm.py is MISSING');
end

unmatched = mIp.Unmatched;
argList = strings(1, 0);
fn = fieldnames(unmatched);
for i = 1:numel(fn)
    key = fn{i};
    val = unmatched.(key);

    % Convert key to --key
    flag = "--" + string(key);

    if islogical(val)
        if val
            argList(end+1) = flag;
        end
    elseif isstring(val) || ischar(val) || isnumeric(val)
        % scalar
        if isscalar(val)
            argList(end + 1) = flag;
            argList(end + 1) = string(val);
        else
            % vector: --key v1 v2 ...
            argList(end + 1) = flag;
            vals = string(val);
            argList = [argList, vals(:).'];
        end
    elseif iscell(val)
        % cell array: --key v1 v2 ...
        argList(end + 1) = flag;
        vals = string(val);
        argList = [argList, vals(:).'];
    else
        % other types: to string
        argList(end + 1) = flag;
        argList(end + 1) = string(val);
    end
end

% Execution
pyscriptPATH = string(pyscriptPATH);
pyexePATH    = string(pyexePATH);
q = @(s) ['"', char(s), '"'];

% cmd = python launcher pyscript [positional args] [--key value ...]
cmdParts = [string(q(pyexePATH)), string(q(launcher)), string(q(pyscriptPATH))];

% append positional args (quoted)
if ~isempty(pyPosArgs)
    posQuoted = join(arrayfun(q, pyPosArgs, 'UniformOutput', false), ' ');
    cmdParts  = [cmdParts, string(posQuoted)];
end

% append name-value args (quoted)
if ~isempty(argList)
    argQuoted = join(arrayfun(q, argList, 'UniformOutput', false), ' ');
    cmdParts  = [cmdParts, string(argQuoted)];
end

cmd = strjoin(cmdParts, ' ');

fprintf('[mu_pydebug_pycharm] Exec: %s\n', cmd);
[status, cmdout] = system(cmd);

if status ~= 0
    warning('mu_pydebug_pycharm:NonZeroExit','Python script execution failed: %d', status);
end

return;
end
