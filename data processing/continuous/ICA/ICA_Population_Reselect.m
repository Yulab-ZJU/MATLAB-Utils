function [comp, ICs, FigTopoICA, FigWave, FigIC] = ICA_Population_Reselect(comp, trialsECOG, windowData)
    % Description: reselect ICs for reconstruction after performing ICA_Population
    % Input:
    %     comp: result of ICA (FieldTrip) without field [trial]
    %     trialsECOG: nTrial*1 cell array of trial data (nCh*nSample matrix)
    %     windowData: time window for [trialsECOG], in ms
    % Output:
    %     comp: result of ICA (FieldTrip) without field [trial]
    %     ICs: the input IC number array for data reconstruction
    %     FigTopoICA: figure of topo of all ICs
    %     FigWave: (1) is raw wave. (2) is reconstructed wave.
    %     FigIC: IC wave

    chs2doICA = comp.chs2doICA;

    % IC topo
    channels = 1:size(trialsECOG{1}, 1);
    badCHs = channels(~ismember(channels, chs2doICA));
    topo = insertRows(comp.topo, badCHs);
    FigTopoICA = plotTopoICA(topo, [8, 8]);
    
    % Origin raw wave
    temp = interpolateBadChs(trialsECOG, badCHs);
    FigWave(1) = plotRawWave(calchMean(temp), calchStd(temp), windowData, "origin");
    scaleAxes(FigWave(1), "y", "cutoffRange", [-100, 100], "symOpts", "max");

    % Remove bad channels in trialsECOG
    trialsECOG = cellfun(@(x) x(chs2doICA, :), trialsECOG, "UniformOutput", false);

    % IC Wave
    temp = comp.unmixing * trialsECOG;
    FigIC = plotRawWave(calchMean(temp), calchStd(temp), windowData, "ICA");
    scaleAxes(FigIC, "y", "cutoffRange", [-50, 50], "symOpts", "max");
    
    k = 'N';
    while ~any(strcmpi(k, {'y', ''}))
        try
            close(FigWave(2));
        end

        ICs = input('Input IC number for data reconstruction (empty for all): ');
        if isempty(ICs)
            ICs = 1:length(chs2doICA);
        end
        badICs = input('Input bad IC number: ');
        ICs(ismember(ICs, badICs)) = [];

        temp = reconstructData(trialsECOG, comp, ICs);
        temp = cellfun(@(x) insertRows(x, badCHs), temp, "UniformOutput", false);
        temp = interpolateBadChs(temp, badCHs);
        FigWave(2) = plotRawWave(calchMean(temp), calchStd(temp), windowICA, "reconstruct");
        scaleAxes(FigWave(2), "y", "on", "symOpts", "max");

        k = validateInput('Press Y or Enter to continue or N to reselect ICs: ', @(x) isempty(x) || any(validatestring(x, {'y', 'n', 'N', 'Y', ''})), 's');
    end

    return;
end