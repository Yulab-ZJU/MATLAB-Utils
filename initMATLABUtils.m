function initMATLABUtils
rootpath = fullfile(fileparts(mfilename("fullpath")));
addpath(rootpath);
addpath(genpath(fullfile(rootpath, "external")));
addpath(genpath(fullfile(rootpath, "toolbox API")));
addpath(genpath(fullfile(rootpath, "user interface")));
addpath(fullfile(rootpath, "callback"));

if ~exist(fullfile(rootpath, "resources", "functionSignatures.json"), "file")
    mkdir(fullfile(rootpath, "resources"));
    copyfile(fullfile(rootpath, "docs", "functionSignatures.json"), fullfile(rootpath, "resources", "functionSignatures.json"));
end