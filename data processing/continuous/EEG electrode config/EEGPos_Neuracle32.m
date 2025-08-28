function EEGPos = EEGPos_Neuracle32()
%% Basic info
EEGPos.name = "Neuracle64";

% channels vector
EEGPos.channels = 1:32;

% channels not to plot
EEGPos.ignore = [];

%% Actual location
% locs file (highest priority, plot in actual location)
EEGPos.locs = readlocs('Neuracle_chan32.loc'); % comment this line to plot in grid

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
EEGPos.grid = [8, 7];

% channel map into grid
EEGPos.map(1:2) = [3,5];
EEGPos.map(3) = 11;
EEGPos.map(4 : 5) = [10,12];
EEGPos.map(6:7) = [9,13];
EEGPos.map(8 : 9) = [17 19];
EEGPos.map(10:11) = [16 20];
EEGPos.map(23) = 39;
EEGPos.map(12) = 25;
EEGPos.map(13 : 14) = [24,26];
EEGPos.map(15 : 16) = [23,27];
EEGPos.map(17:18) = [22,28];
EEGPos.map(19 : 20) = [31,33];
EEGPos.map(21:22) = [30,34];
EEGPos.map(24:25) = [38,40];
EEGPos.map(26:27) = [37,41];
EEGPos.map(28:29) = [45,47];
EEGPos.map(30) = 53;
EEGPos.map(31:32) = [52 54];