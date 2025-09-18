function [status, cmdout] = mu_pydebug_pycharm(pyscriptPATH, pyexePATH, varargin)
%MU_PYDEBUG_PYCHARM  Run python script via MATLAB and debug in PyCharm (via debug server).
%
% INPUTS:
%   REQUIRED:
%     pyscriptPATH  - Full path of python script to run
%     pyexePATH     - Full path of python exe
%                     Must be same as your PyCharm setting
%   NAMEVALUE:
%     Port          - Port number of debug server (default=5678)
%     Other name-value inputs for python script
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
% Usage:
%   1. Start debug server in PyCharm (see NOTES point 2).
%   2. Run MATLAB code:
%      mu_pydebug_pycharm('~\yourscript.py', ...
%                         'C:\Users\YOU\.conda\envs\kilosort\python.exe', ...
%                         'Port', 5678, ...
%                         'param1', val1, 'param2', val2)

% Parse inputs
mIp = inputParser;
mIp.KeepUnmatched = true;
mIp.addRequired("pyscriptPATH", @mu.isTextScalar);
mIp.addRequired("pyexePATH", @mu.isTextScalar);
mIp.addParameter("Port", 5678, @(x) validateattributes(x, 'numeric', {'scalar', 'positive', 'integer'}));
mIp.parse(pyscriptPATH, pyexePATH, varargin{:});
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
if ~isempty(argList)
    argQuoted = join(arrayfun(q, argList, 'UniformOutput', false), ' ');
    cmd = sprintf('%s %s %s %s', q(pyexePATH), q(launcher), q(pyscriptPATH), string(argQuoted));
else
    cmd = sprintf('%s %s %s',    q(pyexePATH), q(launcher), q(pyscriptPATH));
end
fprintf('[mu_pydebug_pycharm] Exec: %s\n', cmd);
[status, cmdout] = system(cmd);

if status ~= 0
    warning('mu_pydebug_pycharm:NonZeroExit','Python script execution failed: %d', status);
end

return;
end