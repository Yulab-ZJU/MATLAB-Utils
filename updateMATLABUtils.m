function updateMATLABUtils(SyncOption)
narginchk(0, 1);
if nargin < 1
    SyncOption = false;
end
mu.syncRepositories([], "RepositoryPaths", fileparts(mfilename("fullpath")), "SyncOption", SyncOption);
