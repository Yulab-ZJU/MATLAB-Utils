function [trialsData, chMean, chStd] = reconstructData(trialsData, comp, ICs)
    % Reconstruct data using ICA result
    % Input:
    %     trialsData: nTrials*1 cell vector with each cell containing an nCh*nSample matrix of data
    %     comp: ICA result of fieldtrip, with fields:
    %           - topo: channel-by-IC
    %           - unmixing: IC-by-channel
    %     ICs: independent component index, range from 1 to size(comp.topo, 2)
    % Principle:
    %     [S] is raw signal and [X] is the acquired data. [S] and [X] are both nCh*nSample data.
    %     Then, S = W * X, where [W] is called an unmixing matrix.
    %     Also, X = inv(W) * S, where inv(W) is the inverse matrix of [W], called a topo matrix.
    %     [W] is a square matrix. So the number of channels and the number of ICs are equal.
    %     [W] is IC-by-channel and inv(W) is channel-by-IC.
    %
    %     To remove an IC that is considered as artifact from your data, get [S] first.
    %     Then, set the column vector of that IC to zeros in the topo matrix.
    %     Finally, reconstruct [X] with the new topo matrix.
    %
    %     S = W * X;
    %     topo = inv(W);
    %     topo(:, ic2remove) = 0;
    %     X = topo * S;

    comp.topo(:, ~ismember(1:size(comp.topo, 2), ICs)) = 0;
    trialsICA = cellfun(@(x) comp.unmixing * x, trialsData, "UniformOutput", false);
    trialsData = cellfun(@(x) comp.topo * x, trialsICA, "UniformOutput", false);
    chMean = calchMean(trialsData);
    chStd = calchStd(trialsData);
    return;
end