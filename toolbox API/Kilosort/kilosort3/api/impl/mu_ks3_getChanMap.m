function chanMap = mu_ks3_getChanMap(nCh, badChs)
narginchk(1, 2);

if nargin < 2
    badChs = [];
end

chanMapRoot = fullfile(mu.getrootpath(fileparts(which('mu_kilosort3')), 2), 'chanMap');

switch nCh
    case 4      % 5*5*6*16 linear array
        chanMap = fullfile(chanMapRoot, 'chan5_5_6_16_kilosortChanMap.mat');
    case 8      % 8*2 linear array
        chanMap = fullfile(chanMapRoot, 'chan8_2_kilosortChanMap.mat');
    case 8.5    % 8*1 linear array
        chanMap = fullfile(chanMapRoot, 'chan8_ch5_kilosortChanMap.mat');
    case 16     % 16*1 linear array
        chanMap = fullfile(chanMapRoot, 'chan16_1_kilosortChanMap.mat');
    case 24     % 24*1 linear array
        chanMap = fullfile(chanMapRoot, 'chan24_1_kilosortChanMap.mat');
    case 24.32  % 24*1 linear array
        chanMap = fullfile(chanMapRoot, 'chan24in32_1_kilosortChanMap.mat');
    case 32     % 16*2 linear array
        chanMap = fullfile(chanMapRoot, 'chan16_2_kilosortChanMap.mat');
    case 31     % 16*2 linear array
        chanMap = fullfile(chanMapRoot, 'chan16_2_1_kilosortChanMap.mat');
    case 128    % RHD
        chanMap = fullfile(chanMapRoot, 'PKU128_kilosortChanMap.mat');
    case 385    % Neuropixels
        chanMap = fullfile(chanMapRoot, 'neuropixPhase3B1_kilosortChanMap.mat');
    otherwise
        error('Unsupported channel number %.2f', nCh);
end

% Generate temporary chan map file
if ~isempty(badChs)
    probe = load(chanMap);
    probe.connected(probe.chanMap(badChs)) = false;
    if ~exist(fullfile(chanMapRoot, 'temp'), "dir")
        mkdir(fullfile(chanMapRoot, 'temp'));
    end
    vars = fieldnames(probe);
    chanMap = fullfile(chanMapRoot, 'temp', 'Temp_chanMap.mat');
    save(chanMap, vars{:});
end

return;
end
