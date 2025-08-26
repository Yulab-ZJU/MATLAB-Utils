function [outbins, nch] = TDT2bins(BLOCKPATHs, varargin)
%% Validate inputs
mIp = inputParser;
mIp.addParameter("Channel", [], @(x) validateattributes(x, 'numeric', {'vector', 'integer', 'positive'}));
mIp.addParameter("Format", 'i16');
mIp.addParameter("ScaleFactor", 1e6, @(x) validateattributes(x, 'numeric', {'scalar', 'positive'}));
mIp.addParameter("dt", 10, @(x) validateattributes(x, 'numeric', {'scalar', 'positive'}));
mIp.addParameter("SkipExisted", true, @(x) validateattributes(x, 'logical', {'scalar'}));
mIp.parse(varargin{:});

CHANNEL = unique(mIp.Results.Channel);
FORMAT = validatestring(mIp.Results.Format, {'i16', 'f32'});
SCALE_FACTOR = mIp.Results.ScaleFactor;
TIME_DELTA = mIp.Results.dt; % sec
skipExisted = mIp.Results.SkipExisted;

BLOCKPATHs = cellstr(BLOCKPATHs);

%% Export to binary file
outbins = cell(numel(BLOCKPATHs), 1);
for blk = 1:numel(BLOCKPATHs)
    BLOCKPATH = BLOCKPATHs{blk};
    SAVEPATH = fullfile(BLOCKPATH, 'Wave.bin');
    outbins{blk} = SAVEPATH;

    if ~exist(BLOCKPATH, "dir")
        error('TDT Block folder %s does not exist', BLOCKPATH);
    end

    if blk == 1
        data = TDTbin2mat(BLOCKPATH, 'TYPE', {'streams'}, 'STORE', 'Wave', 'T2', 0.1);
        fs = data.streams.Wave.fs;
        nch = size(data.streams.Wave.data, 1);
        if isempty(CHANNEL)
            CHANNEL = 1:nch;
        else
            assert(max(CHANNEL) <= nch, 'Channel number should not exceed %d', nch);
        end
    end

    if exist(SAVEPATH, "file")
        fprintf('File already exists: %s', SAVEPATH);
        if ~skipExisted
            key = validateinput('Continue? y/[n] ', @(x) isempty(x) || ismember(string(x), ["y", "n"]), 's');
            if isempty(key) || strcmpi(key, "n")
                continue;
            end
        else
            disp('Skip exporting existed binary file');
        end
    end

    fid = fopen(SAVEPATH, 'wb');
    T1 = 0;
    T2 = T1 + TIME_DELTA;

    data = TDTbin2mat(BLOCKPATH, 'STORE', 'Wave', 'T1', T1, 'T2', T2);
    dataSeg = data.streams.Wave.data(CHANNEL, :);

    % loop through data in TIME_DELTA increments
    while ~isempty(dataSeg)
        if strcmpi(FORMAT, 'i16')
            fwrite(fid, SCALE_FACTOR * reshape(dataSeg, 1, []), 'integer*2');
        elseif strcmpi(FORMAT, 'f32')
            fwrite(fid, SCALE_FACTOR * reshape(dataSeg, 1, []), 'single');
        end

        T1 = T2;
        T2 = T2 + TIME_DELTA;
        try
            data = TDTbin2mat(BLOCKPATH, 'STORE', 'Wave', 'T1', T1, 'T2', T2);
            dataSeg = data.streams.Wave.data(CHANNEL, :);
        catch
            dataSeg = [];
        end
    end

    fprintf('Wrote Wave to output file %s\n', SAVEPATH);
    fprintf('Sampling Rate: %.6f Hz\n', fs);
    fprintf('Num Channels: %d\n', numel(CHANNEL));
    fclose(fid);
end

return;
end