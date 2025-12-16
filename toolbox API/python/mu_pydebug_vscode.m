function [status, cmdout] = mu_pydebug_vscode(pyscriptPATH, pyexePATH, varargin)
%MU_PYDEBUG_VSCODE  Run python script via MATLAB and debug in VS Code (via debugpy).
%
% SYNTAX：
%   status = mu_pydebug_vscode(pyscriptPATH, [pyexePATH])
%   status = mu_pydebug_vscode(..., 'Port', PortNumber, 'param1', val1, 'param2', val2, ...)
%
% INPUTS:
%   REQUIRED:
%     pyscriptPATH  - Full path of python script to run
%     pyexePATH     - Full path of python exe
%                     Must be same as your VS Code setting
%   NAMEVALUE:
%     Port          - Port number of debug server (default=5678)
%     WaitForClient - Switch of debug mode (default=true, debug mode 'on')
%     Other name-value inputs for python script
%
% OUTPUTS:
%     status        - 0: success, other values: failed
%     cmdout        - Output information from command line
%
% NOTES:
%   - Make sure that VS Code uses the same python version as pyexePATH specifies.
%
% Usage:
%   1. Configure launch.json in VS Code:
%      Create .vscode/launch.json in your python script folder:
%      ----------------------------------------------------
%      {
%        "version": "0.2.0",
%        "configurations": [
%          {
%            "name": "Attach to debugpy (MATLAB)",
%            "type": "debugpy",
%            "request": "attach",
%            "connect": {"host": "localhost", "port": 5678},
%            "justMyCode": false
%          }
%        ]
%      }
%      ----------------------------------------------------
%   2. Run MATLAB code:
%      mu_pydebug_vscode('~\yourscript.py', ...
%                        'C:\Users\YOU\.conda\envs\kilosort\python.exe', ...
%                        'Port', 5678, ...
%                        'param1', val1, 'param2', val2)
%   3. Set break points in your python script in VS Code
%   4. Run Python script in VS Code in debug mode with launch.json

% Parse inputs
mIp = inputParser;
mIp.KeepUnmatched = true;
mIp.addRequired("pyscriptPATH", @mu.isTextScalar);
mIp.addRequired("pyexePATH", @mu.isTextScalar);
mIp.addParameter("Port", 5678, @(x) validateattributes(x, 'numeric', {'scalar', 'positive', 'integer'}));
mIp.addParameter("WaitForClient", true, @(x) validateattributes(x, 'logical', {'scalar'}));
mIp.parse(pyscriptPATH, pyexePATH, varargin{:});
port = mIp.Results.Port;

host = '127.0.0.1';
waitForCli = mIp.Results.WaitForClient; % switch of debug
bg = false;

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
dbgPieces = [q(pyexePATH), "-m", "debugpy", "--listen", host + ":" + string(port)];
if waitForCli
    dbgPieces(end + 1) = "--wait-for-client";
end

cmdParts = [dbgPieces, q(pyscriptPATH)];
if ~isempty(argList)
    argQuoted = join(arrayfun(q, argList, 'UniformOutput', false), ' ');
    cmdParts  = [cmdParts, string(argQuoted)];
end

if bg
    if ispc
        fullCmd = "start "" " + strjoin(cmdParts, ' ');
    else
        fullCmd = strjoin(cmdParts, ' ') + " &";
    end
else
    fullCmd = strjoin(cmdParts, ' ');
end

fprintf('[mu_pydebug_vscode] Exec: %s\n', fullCmd);
[status, cmdout] = system(fullCmd);

if status ~= 0
    warning('mu_pydebug_vscode:NonZeroExit','Python script execution failed: %d', status);
end

return;
end
