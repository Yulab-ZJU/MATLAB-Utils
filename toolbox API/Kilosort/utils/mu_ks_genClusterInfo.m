function mu_ks_genClusterInfo(resultsDir, fs)
% mu_ks_genClusterInfo  Generate cluster_info.tsv from Kilosort results
%
% Usage:
%   mu_ks_genClusterInfo(resultsDir, fs)
%
% Inputs:
%   resultsDir - folder containing Kilosort outputs
%   fs         - sampling frequency (Hz)
%
% Output:
%   Writes cluster_info.tsv into resultsDir

arguments
    resultsDir {mustBeTextScalar}
    fs (1,1) double {mustBePositive}
end

outFile = fullfile(resultsDir, 'cluster_info.tsv');
if exist(outFile, "file")
    fprintf('File %s already exists. Skip exporting.\n', outFile);
    return;
end

% Read NPY
spike_clusters  = readNPY(fullfile(resultsDir, 'spike_clusters.npy'));   % N x 1
spike_times     = readNPY(fullfile(resultsDir, 'spike_times.npy'));      % N x 1
spike_templates = readNPY(fullfile(resultsDir, 'spike_templates.npy'));  % N x 1
templates       = readNPY(fullfile(resultsDir, 'templates.npy'));        % nTemplates x nTimepoints x nChannels
channel_map     = readNPY(fullfile(resultsDir, 'channel_map.npy'));      % nChannels x 1

unique_clusters = unique(spike_clusters);
nClusters = numel(unique_clusters);

[cluster_id, ch, n_spikes, fr] = deal(zeros(nClusters, 1));

durationSec = double(max(spike_times)) / fs;

for i = 1:nClusters
    cid = unique_clusters(i);
    cluster_id(i) = cid;

    idx = (spike_clusters == cid);
    n_spikes(i) = sum(idx);
    fr(i) = n_spikes(i) / durationSec;

    % find the dominant template for this cluster
    tmpl_ids = spike_templates(idx);
    if isempty(tmpl_ids)
        ch(i) = -1;
    else
        dom_tmpl = mode(tmpl_ids); % most frequent template index (0-based)
        tmpl = squeeze(templates(dom_tmpl + 1, :, :)); % [nChannels x nTimepoints]

        [~, maxCh] = max(max(abs(tmpl), [], 2), [], 1); % max RMS channel
        ch(i) = channel_map(maxCh);                     % map to physical channel
    end

end

% Output tsv file
T = table(cluster_id, ch, n_spikes, fr);
writetable(T, outFile, 'FileType', 'text', 'Delimiter', '\t');

fprintf('cluster_info.tsv saved at %s\n', outFile);

return;
end
