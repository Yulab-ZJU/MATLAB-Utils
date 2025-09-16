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
%
% Notes:
%   - Assumes Kilosort/Kilosort4 output layout.
%   - spike_templates and channel_map are 0-based indices.
%   - Best channel per cluster is chosen by peak-to-peak amplitude (robust).

arguments
    resultsDir {mustBeTextScalar}
    fs (1,1) double {mustBePositive}
end

outFile = fullfile(resultsDir, 'cluster_info.tsv');
if exist(outFile, "file")
    fprintf('File %s already exists. Skip exporting.\n', outFile);
    return;
end

% ---------- Load required files ----------
reqFiles = { ...
    'spike_clusters.npy', ...
    'spike_times.npy', ...
    'spike_templates.npy', ...
    'templates.npy', ...
    'channel_map.npy' ...
    };

for k = 1:numel(reqFiles)
    f = fullfile(resultsDir, reqFiles{k});
    if ~exist(f, 'file')
        error('Required file missing: %s', f);
    end
end

spike_clusters  = readNPY(fullfile(resultsDir, 'spike_clusters.npy'));   % N x 1 (cluster id per spike)
spike_times     = readNPY(fullfile(resultsDir, 'spike_times.npy'));      % N x 1 (in samples)
spike_templates = readNPY(fullfile(resultsDir, 'spike_templates.npy'));  % N x 1 (0-based template id per spike)
templates       = readNPY(fullfile(resultsDir, 'templates.npy'));        % [nTemplates x nTimepoints x nChannels]
channel_map     = readNPY(fullfile(resultsDir, 'channel_map.npy'));      % [nChannels x 1], 0-based physical ch

% ---------- Basic checks ----------
if isempty(spike_times) || all(spike_times == 0)
    warning('spike_times appears empty or all zeros. Firing rates may be zero.');
end
if size(templates, 3) ~= numel(channel_map)
    warning('templates third dim (%d) != numel(channel_map) (%d).', size(templates,3), numel(channel_map));
end

% ---------- Cluster list & recording duration ----------
unique_clusters = unique(spike_clusters(:), 'stable');    % keep stable ordering
nClusters = numel(unique_clusters);

if isempty(spike_times)
    durationSec = 0;
else
    % spike_times are in sample indices (int64). Use max-min for safety.
    tMin = double(min(spike_times));
    tMax = double(max(spike_times));
    durationSec = max( (tMax - tMin) / fs, eps );         % avoid divide-by-zero
end

% ---------- Preallocate ----------
cluster_id = zeros(nClusters,1, 'like', double(unique_clusters));
ch         = -1 * ones(nClusters,1, 'like', double(1));   % -1 if unknown
n_spikes   = zeros(nClusters,1);
fr         = zeros(nClusters,1);

% ---------- Main loop ----------
for i = 1:nClusters
    cid = unique_clusters(i);
    cluster_id(i) = double(cid);

    idx = (spike_clusters == cid);
    n_spikes(i) = sum(idx);

    fr(i) = n_spikes(i) / durationSec;

    % dominant (most frequent) template for this cluster (0-based)
    tmpl_ids = spike_templates(idx);
    if isempty(tmpl_ids)
        ch(i) = -1;   % no spikes assigned (shouldn't happen, but safe)
        continue;
    end

    % mode of template ids (0-based)
    dom_tmpl = mode(tmpl_ids);

    % Extract template and permute to [nChannels x nTimepoints]
    % templates: [nTemplates x nTimepoints x nChannels]
    tmpl = permute(templates(dom_tmpl + 1, :, :), [3 2 1]);   % [nChannels x nTimepoints]

    % Choose best channel by peak-to-peak amplitude (robust for non-sinusoidal shapes)
    ptp = max(tmpl, [], 2) - min(tmpl, [], 2);                % [nChannels x 1]
    [~, maxChRel] = max(ptp, [], 1);                          % relative index within this recording

    % Map to physical channel id via channel_map (kept 0-based to match KS/Phy)
    ch(i) = double(channel_map(maxChRel));
end

% ---------- Assemble and write TSV ----------
T = table(cluster_id, ch, n_spikes, fr);
% If you want 1-based physical channels in the TSV for human reading, uncomment:
% T.ch = T.ch + 1;

writetable(T, outFile, 'FileType', 'text', 'Delimiter', '\t', 'WriteVariableNames', true);

fprintf('cluster_info.tsv saved at %s\n', outFile);

return;
end
