function trialsData = mu_ica_reconstructData(trialsData, comp, ICs)
% Reconstruct data using ICA result
% Inputs:
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

% Check trial data
[nch, nsample] = mu.checkdata(trialsData);
ntrial = numel(trialsData);

% Ensure IC indices are valid
nIC = size(comp.topo, 2);
assert(all(ICs >= 1 & ICs <= nIC), 'ICs out of range');

% Create modified topo (zero unwanted ICs)
topo_new = comp.topo;
topo_new(:, setdiff(1:nIC, ICs)) = 0;

% Combine into single transformation [nch x nch]
transformMat = topo_new * comp.unmixing;

% Memory check before cat
bytesPerElem = bytesPerElement(trialsData{1});
estBytes = nch * nsample * ntrial * bytesPerElem;
if canUsePage(estBytes)
    % Try batch processing with pagemtimes
    try
        data3D = cat(3, trialsData{:});  % [nch × nsample × ntrial]
        data3D = pagemtimes(transformMat, data3D);

        % Ensure column cell vector
        trialsData = reshape(mat2cell(data3D, nch, nsample, ones(1, ntrial)), [], 1);

        return;
    catch ME
        warning('mu_ica_reconstructData:Fallback', ...
                'Batch processing failed (%s). Using cellfun...', ME.message);
    end
end

trialsData = cellfun(@(x) transformMat * x, trialsData, "UniformOutput", false);
return;
end

%% 
function tf = canUsePage(neededBytes)
    tf = true;
    try
        if ispc
            m = memory;
            availBytes = m.MaxPossibleArrayBytes;
        else
            [~,sysMem] = system('grep MemAvailable /proc/meminfo | awk ''{print $2}''');
            availBytes = str2double(sysMem) * 1024; % kB -> bytes
        end
        if neededBytes > 0.5 * availBytes
            tf = false; % Use at most 50% of available memory
        end
    catch
        % If memory check fails, just try anyway
    end
end

function bytes = bytesPerElement(x)
    switch class(x)
        case 'double'
            bytes = 8;
        case 'single'
            bytes = 4;
        otherwise
            info = whos('x');
            bytes = info.bytes / numel(x);
    end
end