function genClusterInfo(resultsDir, fs)
% genClusterInfo  Generate cluster_info.tsv from Kilosort results
%
% Usage:
%   genClusterInfo(resultsDir, fs)
%
% Inputs:
%   resultsDir - folder containing spike_clusters.npy, spike_times.npy, templates.npy
%   fs         - sampling frequency (Hz)
%
% Output:
%   Writes cluster_info.tsv into resultsDir

arguments
    resultsDir {mustBeTextScalar}
    fs (1,1) double {mustBePositive}
end

if exist(fullfile(resultsDir, 'cluster_info.tsv'), "file")
    fprintf('File %s already exists. Skip exporting.', fullfile(resultsDir, 'cluster_info.tsv'));
end

% Read NPY
spike_clusters = readNPY(fullfile(resultsDir, 'spike_clusters.npy')); % N x 1
spike_times    = readNPY(fullfile(resultsDir, 'spike_times.npy'));    % N x 1
templates      = readNPY(fullfile(resultsDir, 'templates.npy'));      % nTemplates x nChannels x templateLength

unique_clusters = unique(spike_clusters);
nClusters = numel(unique_clusters);

cluster_id = zeros(nClusters,1);
ch         = zeros(nClusters,1);
n_spikes   = zeros(nClusters,1);
fr         = zeros(nClusters,1);
group      = strings(nClusters,1);

durationSec = double(max(spike_times)) / fs;

for i = 1:nClusters
    cid = unique_clusters(i);
    cluster_id(i) = cid;

    idx = find(spike_clusters == cid);
    n_spikes(i) = numel(idx);

    fr(i) = n_spikes(i) / durationSec;

    template_idx = cid + 1;
    if template_idx > size(templates,1)
        ch(i) = -1;
    else
        tmpl = squeeze(templates(template_idx,:,:)); % nChannels x templateLength
        [~, ch(i)] = max(max(abs(tmpl), [], 2));     % find channel with maximum amplitude
    end

    group(i) = "unsorted";
end

% Output tsv file
T = table(cluster_id, ch, n_spikes, fr, group);
outFile = fullfile(resultsDir, 'cluster_info.tsv');
writetable(T, outFile, 'FileType', 'text', 'Delimiter', '\t');

fprintf('cluster_info.tsv saved at %s\n', outFile);

return;
end
