function syncRepositories(opts)
%SYNCREPOSITORIES  Update git repositories under a root path or specific paths.
%
% SYNTAX:
%   mu.syncRepositories("update functions")
%   mu.syncRepositories(..., "SyncOption", true)
%   mu.syncRepositories(..., "RepositoriesRootPath", "D:\")
%   mu.syncRepositories(..., "RepositoryPaths", ["D:\repos1\", "D:\repos2\"])
%   mu.syncRepositories(..., "Remote", )
%
% INPUTS:
%   logstr                - Commit message (string/char, can be empty)
%   SyncOption            - [false] Push changes after pull if true
%   RepositoriesRootPath  - Root path to search for repos (default = location of this file)
%   RepositoryPaths       - Explicit paths of repositories to update

%% Parse inputs
arguments
    opts.log                  {mustBeTextScalar} = ''
    opts.SyncOption           (1,1) logical      = false
    opts.RepositoriesRootPath {mustBeTextScalar} = ''
    opts.RepositoryPaths                         = ''
    opts.Remote               {mustBeTextScalar} = ''
    opts.BranchLocal          {mustBeTextScalar} = ''
    opts.BranchRemote         {mustBeTextScalar} = ''
end

logstr               = opts.log;
SyncOption           = mu.OptionState.create(opts.SyncOption).toLogical;
RepositoriesRootPath = mu.getabspath(opts.RepositoriesRootPath);
RepositoryPaths      = opts.RepositoryPaths;

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
    mustBeText(RepositoryPaths);
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
    remote = opts.Remote;
    if isempty(remote)
        [status, res] = system("git remote");
        if status == 0 && ~isempty(res)
            remotes = split(strtrim(res)); remote = remotes{1};
        else
            remote = "origin";
        end
    end

    branchLocal = opts.BranchLocal;
    if isempty(branchLocal)
        [status, res] = system("git branch --show-current");
        if status == 0
            branchLocal = strtrim(res);
        else
            branchLocal = "master";
        end
    end
    
    branchRemote = opts.BranchRemote;
    if isempty(branchRemote)
        branchRemote = branchLocal;
    end

    fprintf("Pulling from %s/%s...\n", remote, branchRemote);
    pullCmd = sprintf("git pull %s %s:%s", remote, branchRemote, branchLocal);
    [status, msg] = system(pullCmd);
    fprintf(msg);
    fprintf(newline);
    if status ~= 0
        warning("git pull failed in %s\nMessage: %s", repo, msg);
    end

    if SyncOption
        fprintf("Pushing to %s/%s...\n", remote, branchRemote);
        pushCmd = sprintf("git push %s %s:%s", remote, branchLocal, branchRemote);
        [status, msg] = system(pushCmd);
        fprintf(msg);
        if status ~= 0
            warning("git push failed in %s\nMessage: %s", repo, msg);
        end
    end
end

return;
end