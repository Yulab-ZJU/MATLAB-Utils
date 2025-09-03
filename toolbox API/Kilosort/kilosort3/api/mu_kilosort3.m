function mu_kilosort3(binFullPath, ops, SAVEPATH)
% mu_kilosort3 Runs the Kilosort 3 spike sorting pipeline on binary data.
%
% This function executes the full Kilosort 3 workflow for spike sorting neural data.
% It preprocesses the input binary file, runs all main Kilosort steps, and saves results.
%
% Inputs:
%   binFullPath - Full path to the input .bin file containing neural data.
%   ops        - Structure with Kilosort parameters.
%   SAVEPATH   - (Optional) Output folder path for results. Defaults to the .bin file's folder.
%
% Example:
%   Th = [10, 6]; % specify threshold
%   run('.\config\mu_ks3_config_LA32Rat.m'); % returns ops
%   ops.Th = Th;
%   mu_kilosort3('data.bin', ops);
%
% The function will:
%   - Preprocess the data
%   - Extract spikes
%   - Learn templates
%   - Track and sort spikes
%   - Perform final clustering and merging
%   - Save results for further analysis (e.g., with Phy)

narginchk(2, 3);

% checkPyVersion;

if nargin < 3
    SAVEPATH = fileparts(binFullPath);
end

ops.fproc = fullfile(fileparts(binFullPath), 'temp_wh.dat'); % proc file on a fast SSD
ops.fbinary = binFullPath;

%% this block runs all the steps of the algorithm
if ~exist(fullfile(fileparts(binFullPath), 'wh_rez.mat'), "file")
    rez   = preprocessDataSub(ops);
    save(fullfile(fileparts(binFullPath), 'wh_rez.mat'), "rez");
else
    load(fullfile(fileparts(binFullPath), 'wh_rez.mat'), "rez");
end

try
    customInfo = evalin("base", "customInfo");
catch
    customInfo = [];
end

if mu.getor(customInfo, "reMerge", false)
    return
end
rez = datashift2(rez, 1);

[rez, st3, tF] = extract_spikes(rez);

rez = template_learning(rez, tF, st3);

[rez, st3, tF] = trackAndSort(rez);

rez = final_clustering(rez, tF, st3);

try
    rez = find_merges(rez, evalin("base", "customInfo.kilosortAutoMerge"));
catch
    rez = find_merges(rez, 1);
end

mkdir(SAVEPATH)
save(fullfile(SAVEPATH, "kiloRez.mat"), "rez", "-v7.3");
rezToPhy2(rez, SAVEPATH);

% cd(SAVEPATH);
% system('phy template-gui params.py');
end
