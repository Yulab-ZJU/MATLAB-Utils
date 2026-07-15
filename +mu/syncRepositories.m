function syncRepositories(log, opts)
%SYNCREPOSITORIES Update Git repositories under a root path or specific paths.
%
% SYNTAX:
%   mu.syncRepositories('update functions')
%   mu.syncRepositories(..., 'SyncOption', true)
%   mu.syncRepositories(..., 'RepositoriesRootPath', 'D:\')
%   mu.syncRepositories(..., ...
%       'RepositoryPaths', {'D:\repos1', 'D:\repos2'})
%   mu.syncRepositories(..., 'Remote', 'origin')
%   mu.syncRepositories(..., 'BranchLocal', 'master')
%   mu.syncRepositories(..., 'BranchRemote', 'main')
%   mu.syncRepositories(..., 'AbortOnConflict', false)
%
% INPUTS:
%   log
%       Commit message. When empty, an automatic message is generated.
%
%   SyncOption
%       Push the local branch after a successful merge.
%
%   RepositoriesRootPath
%       Root path used to recursively search for Git repositories.
%
%   RepositoryPaths
%       Explicit repository paths. When supplied, recursive searching is
%       skipped.
%
%   Remote
%       Remote name. When empty, the upstream remote is used. If no
%       upstream is configured, 'internal', 'origin', or the first
%       available remote is selected in that order.
%
%   BranchLocal
%       Local branch to update. When empty, the currently checked-out
%       branch is used.
%
%   BranchRemote
%       Remote branch to fetch and merge. When empty, the configured
%       upstream branch or BranchLocal is used.
%
%   AbortOnConflict
%       Abort and restore the pre-merge state when a merge conflict occurs.
%       Default is true. When false, the conflicted merge state is retained
%       for manual resolution.
%
% NOTES:
%   Synchronization is performed using:
%
%       git fetch <remote> <remote branch>
%       git merge --no-edit FETCH_HEAD
%
%   This permits both fast-forward updates and ordinary merge commits.
%   The --no-edit option prevents Git from opening Vim or another editor
%   for the automatically generated merge commit message.

arguments
    log                       {mustBeTextScalar} = ''

    opts.log                  {mustBeTextScalar} = ''
    opts.SyncOption           (1,1) logical      = false
    opts.RepositoriesRootPath {mustBeTextScalar} = ''
    opts.RepositoryPaths      {mustBeText}       = ''
    opts.Remote               {mustBeTextScalar} = ''
    opts.BranchLocal          {mustBeTextScalar} = ''
    opts.BranchRemote         {mustBeTextScalar} = ''
    opts.AbortOnConflict      (1,1) logical      = true
end

%% Parse inputs

if ~isempty(opts.log) && isempty(log)
    log = opts.log;
end
logstr = char(string(log));
SyncOption = opts.SyncOption;
RepositoryPaths = opts.RepositoryPaths;

if isempty(opts.RepositoriesRootPath)
    RepositoriesRootPath = mu.getabspath('');
else
    RepositoriesRootPath = mu.getabspath(opts.RepositoriesRootPath);
end

%% Get current user name

[status, currentUser] = system('whoami');

if status ~= 0 || isempty(strtrim(currentUser))
    currentUser = 'unknown user';
else
    currentUser = strtrim(currentUser);

    if contains(currentUser, '\')
        currentUserParts = strsplit(currentUser, '\');
        currentUser = currentUserParts{end};
    end
end

%% Find repositories

if isempty(RepositoryPaths)
    fprintf( ...
        'Searching for Git repositories in: %s\n', ...
        RepositoriesRootPath);

    gitDirs = dir(fullfile( ...
        RepositoriesRootPath, ...
        '**', ...
        '.git'));

    if isempty(gitDirs)
        error( ...
            'mu:syncRepositories:NoRepository', ...
            'No Git repositories found in %s.', ...
            RepositoriesRootPath);
    end

    % The folder containing .git is the repository root.
    RepositoryPaths = unique( ...
        {gitDirs.folder}', ...
        'stable');

    fprintf('The following Git repositories were found:');

    for repoIndex = 1:numel(RepositoryPaths)
        fprintf('\n  %s', RepositoryPaths{repoIndex});
    end

    fprintf('\n');

else
    RepositoryPaths = cellstr(RepositoryPaths);
    RepositoryPaths = cellfun( ...
        @mu.getabspath, ...
        RepositoryPaths, ...
        'UniformOutput', false);

    for repoIndex = 1:numel(RepositoryPaths)
        repo = RepositoryPaths{repoIndex};

        gitMarker = fullfile(repo, '.git');

        assert( ...
            isfolder(gitMarker) || isfile(gitMarker), ...
            'mu:syncRepositories:NotRepository', ...
            'No Git repository found in %s.', ...
            repo);
    end
end

%% Synchronize each repository

currentPath = pwd;
cleanupObj = onCleanup(@() cd(currentPath));

for repoIndex = 1:numel(RepositoryPaths)
    repo = RepositoryPaths{repoIndex};

    fprintf( ...
        '\n=== Processing repository: %s ===\n', ...
        repo);

    try
        cd(repo);
    catch ME
        warning( ...
            'mu:syncRepositories:CannotChangeDirectory', ...
            'Cannot change directory to %s. Repository skipped.\n%s', ...
            repo, ...
            ME.message);
        continue;
    end

    %% Confirm that the directory is a Git work tree

    [status, msg] = system( ...
        'git rev-parse --is-inside-work-tree');

    if status ~= 0 || ~strcmpi(strtrim(msg), 'true')
        printCommandOutput(msg);

        warning( ...
            'mu:syncRepositories:NotRepository', ...
            'Not a Git repository: %s. Repository skipped.', ...
            repo);
        continue;
    end

    %% Determine the currently checked-out branch

    [status, currentBranch] = system( ...
        'git branch --show-current');

    currentBranch = strtrim(currentBranch);

    if status ~= 0 || isempty(currentBranch)
        warning( ...
            'mu:syncRepositories:DetachedHead', ...
            ['Cannot determine the current branch in %s. ' ...
             'The repository may be in detached HEAD state. ' ...
             'Repository skipped.'], ...
            repo);
        continue;
    end

    branchLocal = char(string(opts.BranchLocal));

    if isempty(branchLocal)
        branchLocal = currentBranch;

    elseif ~strcmp(branchLocal, currentBranch)
        warning( ...
            'mu:syncRepositories:BranchMismatch', ...
            ['The currently checked-out branch is ''%s'', but ' ...
             'BranchLocal is ''%s''.\n' ...
             'The repository was not modified.'], ...
            currentBranch, ...
            branchLocal);
        continue;
    end

    %% Do not operate on an unfinished merge

    [mergeHeadStatus, ~] = system( ...
        'git rev-parse -q --verify MERGE_HEAD');

    if mergeHeadStatus == 0
        warning( ...
            'mu:syncRepositories:MergeInProgress', ...
            ['An unfinished merge already exists in %s.\n' ...
             'Resolve or abort the existing merge before synchronizing.'], ...
            repo);
        continue;
    end

    %% Stage and commit local changes

    [status, gitStatus] = system( ...
        'git status --porcelain');

    if status ~= 0
        printCommandOutput(gitStatus);

        warning( ...
            'mu:syncRepositories:StatusFailed', ...
            'Unable to read Git status in %s. Repository skipped.', ...
            repo);
        continue;
    end

    if isempty(strtrim(gitStatus))
        fprintf('No changes to commit.\n');

    else
        fprintf('Local changes detected. Staging files...\n');

        [status, msg] = system('git add -A');
        printCommandOutput(msg);

        if status ~= 0
            warning( ...
                'mu:syncRepositories:AddFailed', ...
                'git add failed in %s. Repository skipped.', ...
                repo);
            continue;
        end

        % Verify that something was actually staged.
        [diffStatus, ~] = system( ...
            'git diff --cached --quiet');

        if diffStatus == 0
            fprintf('No staged changes to commit.\n');

        else
            if isempty(logstr)
                currentTime = char(datetime( ...
                    'now', ...
                    'Format', 'yyyy-MM-dd HH:mm:ss'));

                commitMsg = sprintf( ...
                    'Update %s by %s', ...
                    currentTime, ...
                    currentUser);
            else
                commitMsg = logstr;
            end

            % Use a temporary message file rather than embedding the commit
            % message directly in a shell command. This avoids problems
            % with quotes and shell metacharacters in commit messages.
            commitMessageFile = [tempname, '.txt'];
            commitFileCleanup = onCleanup( ...
                @() deleteFileIfExisting(commitMessageFile));

            fileID = fopen( ...
                commitMessageFile, ...
                'w', ...
                'n', ...
                'UTF-8');

            if fileID < 0
                warning( ...
                    'mu:syncRepositories:CommitMessageFileFailed', ...
                    ['Cannot create a temporary commit message file. ' ...
                     'Repository skipped.']);
                continue;
            end

            fileCleanup = onCleanup(@() fcloseIfOpen(fileID));

            fprintf(fileID, '%s\n', commitMsg);
            fclose(fileID);
            fileID = -1;

            commitCmd = sprintf( ...
                'git commit -F "%s"', ...
                commitMessageFile);

            fprintf('Committing local changes...\n');

            [status, msg] = system(commitCmd);
            printCommandOutput(msg);

            clear fileCleanup commitFileCleanup;

            if status ~= 0
                warning( ...
                    'mu:syncRepositories:CommitFailed', ...
                    'git commit failed in %s. Repository skipped.', ...
                    repo);
                continue;
            end
        end
    end

    %% Determine the remote

    remote = char(string(opts.Remote));

    if isempty(remote)
        upstreamRemoteCmd = sprintf( ...
            'git config --get branch."%s".remote', ...
            branchLocal);

        [status, configuredRemote] = system( ...
            upstreamRemoteCmd);

        configuredRemote = strtrim(configuredRemote);

        if status == 0 && ~isempty(configuredRemote)
            remote = configuredRemote;

        else
            [status, remoteOutput] = system('git remote');

            if status ~= 0 || isempty(strtrim(remoteOutput))
                warning( ...
                    'mu:syncRepositories:NoRemote', ...
                    'No Git remote was found in %s. Repository skipped.', ...
                    repo);
                continue;
            end

            remotes = splitlines(strtrim(string(remoteOutput)));
            remotes(remotes == '') = [];

            if any(remotes == 'internal')
                remote = 'internal';

            elseif any(remotes == 'origin')
                remote = 'origin';

            else
                remote = char(remotes(1));
            end
        end
    end

    %% Verify that the selected remote exists

    verifyRemoteCmd = sprintf( ...
        'git remote get-url "%s"', ...
        remote);

    [status, remoteURL] = system(verifyRemoteCmd);

    if status ~= 0
        printCommandOutput(remoteURL);

        warning( ...
            'mu:syncRepositories:RemoteNotFound', ...
            'Remote ''%s'' does not exist in %s. Repository skipped.', ...
            remote, ...
            repo);
        continue;
    end

    %% Determine the remote branch

    branchRemote = char(string(opts.BranchRemote));

    if isempty(branchRemote)
        upstreamBranchCmd = sprintf( ...
            'git config --get branch."%s".merge', ...
            branchLocal);

        [status, mergeReference] = system( ...
            upstreamBranchCmd);

        mergeReference = strtrim(string(mergeReference));

        if status == 0 && ...
                isscalar(mergeReference) && ...
                startsWith(mergeReference, 'refs/heads/')

            branchRemote = char(extractAfter( ...
                mergeReference, ...
                'refs/heads/'));
        else
            branchRemote = branchLocal;
        end
    end

    %% Fetch the remote branch

    fprintf( ...
        'Fetching from %s/%s...\n', ...
        remote, ...
        branchRemote);

    fetchCmd = sprintf( ...
        'git fetch --prune "%s" "%s"', ...
        remote, ...
        branchRemote);

    [fetchStatus, fetchMsg] = system(fetchCmd);
    printCommandOutput(fetchMsg);

    if fetchStatus ~= 0
        warning( ...
            'mu:syncRepositories:FetchFailed', ...
            'git fetch failed in %s.\nMessage: %s', ...
            repo, ...
            strtrim(fetchMsg));
        continue;
    end

    %% Merge FETCH_HEAD into the local branch

    fprintf( ...
        'Merging %s/%s into %s...\n', ...
        remote, ...
        branchRemote, ...
        branchLocal);

    % --no-edit accepts Git's automatically generated merge message.
    % It therefore avoids opening Vim and requiring :wq.
    mergeCmd = 'git merge --no-edit FETCH_HEAD';

    [mergeStatus, mergeMsg] = system(mergeCmd);
    printCommandOutput(mergeMsg);

    if mergeStatus ~= 0
        [~, conflictFiles] = system( ...
            'git diff --name-only --diff-filter=U');

        conflictFiles = strtrim(conflictFiles);

        [mergeHeadStatus, ~] = system( ...
            'git rev-parse -q --verify MERGE_HEAD');

        mergeInProgress = mergeHeadStatus == 0;

        if ~isempty(conflictFiles)
            fprintf( ...
                2, ...
                'Merge conflicts detected in the following files:\n%s\n', ...
                conflictFiles);
        end

        if opts.AbortOnConflict && mergeInProgress
            fprintf('Aborting the incomplete merge...\n');

            [abortStatus, abortMsg] = system( ...
                'git merge --abort');

            printCommandOutput(abortMsg);

            if abortStatus == 0
                warning( ...
                    'mu:syncRepositories:MergeAborted', ...
                    ['git merge failed in %s. The incomplete merge was ' ...
                     'aborted and the original local state was restored.' ...
                     '\nMessage: %s'], ...
                    repo, ...
                    strtrim(mergeMsg));
            else
                warning( ...
                    'mu:syncRepositories:MergeAbortFailed', ...
                    ['git merge failed in %s and could not be aborted.' ...
                     '\nResolve the repository state manually.' ...
                     '\nMessage: %s'], ...
                    repo, ...
                    strtrim(abortMsg));
            end

        elseif mergeInProgress
            warning( ...
                'mu:syncRepositories:MergeConflict', ...
                ['git merge failed in %s. The conflicted merge state ' ...
                 'was retained for manual resolution.' ...
                 '\nMessage: %s'], ...
                repo, ...
                strtrim(mergeMsg));

        else
            warning( ...
                'mu:syncRepositories:MergeFailed', ...
                'git merge failed in %s.\nMessage: %s', ...
                repo, ...
                strtrim(mergeMsg));
        end

        % Never push after a failed merge.
        continue;
    end

    %% Push after a successful merge

    if SyncOption
        fprintf( ...
            'Pushing %s to %s/%s...\n', ...
            branchLocal, ...
            remote, ...
            branchRemote);

        pushCmd = sprintf( ...
            'git push "%s" "%s:%s"', ...
            remote, ...
            branchLocal, ...
            branchRemote);

        [pushStatus, pushMsg] = system(pushCmd);
        printCommandOutput(pushMsg);

        if pushStatus ~= 0
            warning( ...
                'mu:syncRepositories:PushFailed', ...
                'git push failed in %s.\nMessage: %s', ...
                repo, ...
                strtrim(pushMsg));
        end
    end
end

end


function printCommandOutput(msg)
%PRINTCOMMANDOUTPUT Safely print output returned by SYSTEM.

if isempty(msg)
    return;
end

fprintf('%s', msg);

if msg(end) ~= newline
    fprintf('\n');
end

end


function deleteFileIfExisting(filePath)
%DELETEFILEIFEXISTING Delete a file when it exists.

if isfile(filePath)
    delete(filePath);
end

end


function fcloseIfOpen(fileID)
%FCLOSEIFOPEN Close a valid file identifier.

if isnumeric(fileID) && isscalar(fileID) && fileID >= 0
    try
        fclose(fileID);
    catch
    end
end

end