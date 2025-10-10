function mu_kilosort3(binFullPath, ops, varargin)
%MU_KILOSORT3  Run the Kilosort 3 spike sorting pipeline on binary data.
%
% This function executes the full Kilosort 3 workflow for spike sorting neural data.
% It preprocesses the input binary file, runs all main Kilosort steps, and saves results.
%
% Inputs:
%   binFullPath  - Full path to the input .bin file containing neural data.
%   ops          - Structure with Kilosort parameters.
%   resultsDir   - (Optional) Output folder path for results. Defaults to the .bin file's folder.
%   keepWhFile   - (Namevalue) Keep whitened binary file after sorting (default=true).
%
% Example:
%   ops = mu_ks3_config("chanMap", "probe.mat", ...
%                       "fs", 30e3, ...
%                       "NchanTOT", 128, ...
%                       "Th", [9, 8]);
%   resultsDir = 'kilosort3';
%   mu_kilosort3('data.bin', ops, resultsDir);
%
% The function will:
%   - Preprocess the data
%   - Extract spikes
%   - Learn templates
%   - Track and sort spikes
%   - Perform final clustering and merging
%   - Save results for further analysis (e.g., with Phy2)

mIp = inputParser;
mIp.addRequired("binFullPath", @mustBeTextScalar);
mIp.addRequired("ops", @(x) validateattributes(x, 'struct', {'scalar'}));
mIp.addOptional("resultsDir", fileparts(binFullPath), @mustBeTextScalar);
mIp.addParameter("KeepWhFile", mu.OptionState.On, @mu.OptionState.validate);
mIp.parse(binFullPath, ops, varargin{:});

resultsDir = mIp.Results.resultsDir;
KeepWhFile = mu.OptionState.create(mIp.Results.KeepWhFile);

ops.fproc = fullfile(fileparts(binFullPath), 'temp_wh.dat'); % proc file on a fast SSD
ops.fbinary = binFullPath;

%% this block runs all the steps of the algorithm
if ~exist(fullfile(fileparts(binFullPath), 'wh_rez.mat'), "file")
    rez = preprocessDataSub(ops);
    save(fullfile(fileparts(binFullPath), 'wh_rez.mat'), "rez");
else
    load(fullfile(fileparts(binFullPath), 'wh_rez.mat'), "rez");
end

rez = datashift2(rez, 1);

[rez, st3, tF] = extract_spikes(rez);

rez = template_learning(rez, tF, st3);

[rez, st3, tF] = trackAndSort(rez);

rez = final_clustering(rez, tF, st3);

rez = find_merges(rez, 1);

if ~exist(resultsDir, "dir")
    mkdir(resultsDir);
end

rezToPhy2(rez, resultsDir);

if ~KeepWhFile.toLogical
    delete(ops.fproc);
end

return;
end
