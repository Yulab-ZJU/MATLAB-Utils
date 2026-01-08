function syncRepositories(varargin)
%SYNCREPOSITORIES  Update git repositories under a root path or specific paths.
%
% SYNTAX:
%   mu.syncRepositories("update functions")
%   mu.syncRepositories("msg", "SyncOption", true)
%   mu.syncRepositories("msg", "RepositoriesRootPath", "D:\")
%   mu.syncRepositories("msg", "RepositoryPaths", ["D:\repos1\", "D:\repos2\"])
%
% INPUTS:
%   logstr                - Commit message (string/char, can be empty)
%   SyncOption            - [false] Push changes after pull if true
%   RepositoriesRootPath  - Root path to search for repos (default = location of this file)
%   RepositoryPaths       - Explicit paths of repositories to update

%% Parse inputs
mIp = inputParser;
mIp.addOptional("logstr", '', @(x) isempty(x) || mu.isTextScalar(x));
mIp.addParameter("SyncOption", mu.OptionState.Off, @mu.OptionState.validate);
mIp.addParameter("RepositoriesRootPath", mu.getrootpath(fileparts(mfilename("fullpath")), 1), @(x) mu.isTextScalar(x));
mIp.addParameter("RepositoryPaths", [], @(x) iscellstr(x) || isstring(x) || (ischar(x) && isStringScalar(string(x))));
mIp.parse(varargin{:});

logstr               = mIp.Results.logstr;
SyncOption           = mu.OptionState.create(mIp.Results.SyncOption);
RepositoriesRootPath = mu.getabspath(mIp.Results.RepositoriesRootPath);
RepositoryPaths      = mIp.Results.RepositoryPaths;

%% Get user name
[~, currentUser] = system("whoami");
currentUser = strtrim(currentUser);
if contains(currentUser, '\')
    currentUser = split(currentUser, '\');
    currentUser = currentUser{end};
end

%% Find repositories
if isempty(RepositoryPaths)
    fprintf("Searching for GIT repositories in: %s\n", RepositoriesRootPath);
    gitDirs = dir(fullfile(RepositoriesRootPath, "**", ".git"));
    RepositoryPaths = cellfun(@(x) mu.getrootpath(x, 1), unique({gitDirs.folder})', "UniformOutput", false);

    if isempty(RepositoryPaths)
        error("No GIT repositories found");
    else
        fprintf("The following GIT repositories are found:");
        cellfun(@(x) fprintf("\n  %s", x), RepositoryPaths);
    end

else
    RepositoryPaths = cellfun(@mu.getabspath, cellstr(RepositoryPaths), "UniformOutput", false);
    cellfun(@(x) assert(exist(fullfile(x, '.git'), "dir"), 'No GIT repository found in %s', x), RepositoryPaths);
end

%% Sync each repository
currentPath = pwd;
cleanupObj = onCleanup(@() cd(currentPath));

for rIndex = 1:numel(RepositoryPaths)
    repo = RepositoryPaths{rIndex};
    fprintf("\n=== Processing repository: %s ===\n", repo);

    try
        cd(repo);
    catch
        warning("Cannot change directory to %s. Skipped.", repo);
        continue;
    end

    % Check if repo
    [status, msg] = system("git rev-parse --is-inside-work-tree");
    if status ~= 0
        disp(msg);
        warning("Not a git repository: %s", repo);
        continue;
    end

    % Stage and commit if needed
    [status, ~] = system("git diff --quiet"); % 0 = clean
    if status ~= 0
        system("git status");
        system("git add .");
        if isempty(logstr)
            commitMsg = sprintf("update %s by %s", string(datetime), currentUser);
        else
            commitMsg = logstr;
        end
        commitMsg = strrep(commitMsg, '"', '""'); % escape quotes
        system(sprintf('git commit -m "%s"', commitMsg));
    else
        fprintf("No changes to commit.\n");
    end

    % Pull & optionally push
    [status, msg] = system("git pull");
    fprintf(msg);
    fprintf(newline);
    if status ~= 0
        warning("git pull failed in %s\nMessage: %s", repo, msg);
    end

    if SyncOption.toLogical
        [status, msg] = system("git push");
        fprintf(msg);
        if status ~= 0
            warning("git push failed in %s\nMessage: %s", repo, msg);
        end
    end
end

return;
end