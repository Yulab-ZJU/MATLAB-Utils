function EEGPos = EEGPos_Neuroscan64()
%% Basic info
EEGPos.name = "Neuroscan64";

% channels vector
EEGPos.channels = 1:64;

% channels not to plot
EEGPos.ignore = [33, 43, 60, 64];

%% Actual location
% locs file (highest priority, plot in actual location)
EEGPos.locs = readlocs('Neuroscan_chan64.loc'); % comment this line to plot in grid

%% Channel Alias
EEGPos.channelNames = {EEGPos.locs.labels}';

%% Neighbours
% search for root path of fieldtrip
ftRootPath = fileparts(which("ft_defaults"));

% load standard 10-20 system file
elec  = ft_read_sens(fullfile(ftRootPath, 'template\electrode\standard_1020.elc'));
elec  = ft_convert_units(elec,  'mm');

% only include electrodes in standard 10-20 system
idx = ismember(upper(elec.label), upper(EEGPos.channelNames));
elec.chanpos  = elec.chanpos (idx, :);
elec.chantype = elec.chantype(idx);
elec.chanunit = elec.chanunit(idx);
elec.elecpos  = elec.elecpos (idx, :);
elec.label    = elec.label   (idx);

% find neighbours
cfg = [];
cfg.elec = elec;
cfg.method = 'distance';
neighbours_temp = ft_prepare_neighbours(cfg)';

neighbours = struct("label", EEGPos.channelNames);
for index = 1:length(neighbours)
    idx = ismember({neighbours_temp.label}, neighbours(index).label);
    if any(idx)
        neighbours(index).neighblabel = neighbours_temp(idx).neighblabel;
        neighbours(index).neighbch = find(ismember(EEGPos.channelNames, neighbours(index).neighblabel));
    end
end

EEGPos.neighbours = neighbours;

%% Grid
% grid size
EEGPos.grid = [10, 9]; % row-by-column

% channel map into grid
EEGPos.map(1:3) = 4:6;
EEGPos.map(4:5) = [13, 15];
EEGPos.map(6 : 14) = 19:27;
EEGPos.map(15 : 23) = 28:36;
EEGPos.map(24 : 32) = 37:45;
EEGPos.map(33) = 82;
EEGPos.map(34 : 42) = 46:54;
EEGPos.map(43) = 90;
EEGPos.map(44 : 52) = 55:63;
EEGPos.map(53 : 59) = 65:71;
EEGPos.map(60) = 85;
EEGPos.map(61 : 63) = 76:78;
EEGPos.map(64) = 87;
