function EEGPos = EEGPos_Neuracle64()
%% Basic info
EEGPos.name = "Neuracle64";

% channels vector
EEGPos.channels = 1:64;

% channels not to plot
EEGPos.ignore = 60:64;

%% Actual location
% locs file (highest priority, plot in actual location)
EEGPos.locs = readlocs('Neuracle_chan64.loc'); % comment this line to plot in grid

% adjust
[~, ~, Th, Rd, ~] = readlocs(EEGPos.locs);
Th = pi / 180 * Th; % convert degrees to radians
Rd(48:49) = Rd(48:49) + 0.01;
Rd(55:56) = Rd(55:56) + 0.05;
Th(53) = Th(53) - pi / 60;
Th(54) = Th(54) + pi / 60;
Th = Th / pi * 180; % convert radians to degrees
EEGPos.locs = mu.addfield(EEGPos.locs, "theta", Th(:));
EEGPos.locs = mu.addfield(EEGPos.locs, "radius", Rd(:));

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
EEGPos.map(1:3) = [5, 3, 7];
EEGPos.map(4:7) = [12, 16, 10, 18];
EEGPos.map(8) = 23;
EEGPos.map(9:2:15) = 22:-1:19;
EEGPos.map(10:2:16) = 24:27;
EEGPos.map(17) = 32;
EEGPos.map(18:2:24) = 31:-1:28;
EEGPos.map(19:2:25) = 33:36;
EEGPos.map(26) = 41;
EEGPos.map(27:2 : 33) = 40:-1:37;
EEGPos.map(28:2 : 34) = 42:45;
EEGPos.map(35:2:41 ) = 49:-1:46;
EEGPos.map(36:2:42) = 51:54;
EEGPos.map(43) = 59;
EEGPos.map(44:2:48 ) = 57:-1:55;
EEGPos.map(45:2:49) = 61:63;
EEGPos.map(50) = 68;
EEGPos.map(51:2:55 ) = 67:-1:65;
EEGPos.map(52:2:56) = 69:71;
EEGPos.map(57:59) = [77, 76, 78];
EEGPos.map(60:64) = [82, 84, 86, 88, 90];
