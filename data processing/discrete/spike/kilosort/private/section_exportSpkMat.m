function section_exportSpkMat(RESPATHs, nsamples, fs)
% Read from NPY files and align to start point of each block
[spikeIdx, clusterIdx] = deal(cell(numel(RESPATHs), 1));
for index = 1:numel(RESPATHs)
    [spikeIdx{index}, clusterIdx{index}] = parseNPY(RESPATHs{index});
    if index > 1
        spikeIdx{index} = spikeIdx{index} - nsamples(index - 1);
    end
end

% Convert to sec
spikeTimes = cellfun(@(x) x / fs, spikeIdx, "UniformOutput", false);

% 

return;
end