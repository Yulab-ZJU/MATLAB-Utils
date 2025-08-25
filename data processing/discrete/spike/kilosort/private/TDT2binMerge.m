function TDT2binMerge(BLOCKPATHs, MERGEFILEPATH, CHANNEL, FORMAT, SCALE_FACTOR)
%% Validate inputs
narginchk(2, 5);

BLOCKPATHs = cellstr(BLOCKPATHs);

mustBeTextScalar(MERGEFILEPATH);
if exist(MERGEFILEPATH, "file")
    warning('File already exists: %s', MERGEFILEPATH);
    key = validateinput('Continue? y/[n] ', @(x) isempty(x) || ismember(string(x), ["y", "n"]), 's');
    if isempty(key) || strcmpi(key, "n")
        return;
    end
end

data = TDTbin2mat(BLOCKPATHs{1}, 'TYPE', {'streams'}, 'STORE', 'Wave', 'T2', 0.5);
fs = data.streams.Wave.fs;
if nargin < 3
    CHANNEL = 1:size(data.streams.Wave.data, 1);
end
if nargin < 4
    FORMAT = 'i16';
end
if nargin < 5
    SCALE_FACTOR = 1e6;
end

TIME_DELTA = 10; % sec

%% Export to binary file
fid = fopen(MERGEFILEPATH, 'wb');
nsampleBLOCK = cell(numel(BLOCKPATHs), 1);
for blk = 1:numel(BLOCKPATHs)
    T1 = 0;
    T2 = T1 + TIME_DELTA;

    data = TDTbin2mat(BLOCKPATHs{blk}, 'STORE', 'Wave', 'T1', T1, 'T2', T2);
    dataSeg = data.streams.Wave.data(CHANNEL, :);
    loopN = 1;
    nsampleBLOCK{blk}(loopN) = size(dataSeg, 2);

    % loop through data in 10 second increments
    while ~isempty(dataSeg)
        if strcmpi(FORMAT, 'i16')
            fwrite(fid, SCALE_FACTOR * reshape(dataSeg, 1, []), 'integer*2');
        elseif strcmpi(FORMAT, 'f32')
            fwrite(fid, SCALE_FACTOR * reshape(dataSeg, 1, []), 'single');
        else
            warning('Format %s not recognized. Use i16 or f32', FORMAT);
            break;
        end

        T1 = T2;
        T2 = T2 + TIME_DELTA;
        try
            data = TDTbin2mat(BLOCKPATHs{blk}, 'STORE', 'Wave', 'T1', T1, 'T2', T2);
            dataSeg = data.streams.Wave.data(CHANNEL, :);
            loopN = loopN + 1;
            nsampleBLOCK{blk}(loopN) = size(dataSeg, 2);
        catch
            dataSeg = [];
        end
    end

    fprintf('Wrote Wave to output file %s\n', MERGEFILEPATH);
    fprintf('Sampling Rate: %.6f Hz\n', fs);
    fprintf('Num Channels: %d\n', numel(CHANNEL));
end
fclose(fid);

nsampleBLOCK = cellfun(@sum, nsampleBLOCK);

save(fullfile(fileparts(MERGEFILEPATH), 'mergePara.mat'), 'nsampleBLOCK', 'BLOCKPATHs');

return;
end


