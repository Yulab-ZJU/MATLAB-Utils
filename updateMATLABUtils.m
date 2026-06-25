function updateMATLABUtils(SyncOption, remote)
%UPDATEMATLABUTILS Update MATLAB-Utils repository using local git remote.
%
% updateMATLABUtils()
%   Pull from the local default remote detected by mu.syncRepositories.
%
% updateMATLABUtils(true)
%   Pull and then push to the local default remote.
%
% updateMATLABUtils(true, "internal")
%   Explicitly use remote "internal".

narginchk(0, 2);

if nargin < 1 || isempty(SyncOption)
    SyncOption = false;
end

if nargin < 2 || isempty(remote)
    % Leave empty so mu.syncRepositories will detect the local remote.
    % This avoids hard-coding "origin" and supports remotes such as "internal".
    remote = '';
end

mu.syncRepositories( ...
    "log", '', ...
    "RepositoryPaths", fileparts(mfilename("fullpath")), ...
    "SyncOption", SyncOption, ...
    "Remote", remote);

end