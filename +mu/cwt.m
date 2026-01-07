function [cwtres, f, coi] = cwt(trialsData, fs, varargin)
%CWT  Perfrom continuous wavelet transform (cwt) on multi-channel and
%     multi-trial data using parallel computation on GPU.
%
% SYNTAX:
%     [cwtres, f, coi] = mu.cwt(...)
%     mu.cwt(trialsData, fs)
%     mu.cwt(trialsData, fs, segNum)
%     mu.cwt(..., "mode", "auto | CPU | GPU")
%     mu.cwt(..., "outType", "raw | power | phase" | "freq")
%     mu.cwt(..., "tPad", tPad)
%
% INPUTS:
%   REQUIRED:
%     trialsData  - A nTrial*1 cell, or a nCh*nTime matrix for a single trial.
%                   The input data should be type 'double'.
%   OPTIONAL:
%     segNum  - The number of waves to combine for computation in a single loop. (default=10)
%               If set 1, work in non-parallel mode, which uses "CPU" only and is prior to [mode].
%   NAME-VALUE:
%     mode     - Work mode
%                "auto": try GPU first and then turn to CPU. (default)
%                "CPU" : use CPU only for computation.
%                "GPU" : use GPU first and then turn to CPU for the rest part.
%     tPad     - The total duration of two-sided zero padding, in sec (default=[] for no padding)
%     outType  - The output [cwtres] is a nTrial*nCh*nFreq*nTime matrix.
%                "raw"  : [cwtres] is a complex double matrix. (default)
%                "power": [cwtres] is returned as abs(cwtres).
%                "phase": [cwtres] is returned as angle(cwtres).
%                "freq" : return [f] only.
%     wavelet  - "morse" | "amor" ("morlet", default) | "bump"
%
% OUTPUTS:
%     cwtres  - [nTrial x nCh x nFreq x nTime] matrix, depending on 'outType'
%     f       - Frequency column vector, in descending order
%     coi     - Cone of influence ([nTime x 1])
%
% NOTES:
%   1. There are potential risks of spectrum leakage resulted by coi at low frequencies,
%      especially at the borders. To avoid undesired results, tailor and pad your data.
%      (Update 20241228: padding procedure is now available using name-value input "tPad")
%   2. WARNING ISSUES
%      If the error CUDA_ERROR_OUT_OF_MEMORY occurs, restart your computer and delete the
%      recent-created folders 'Jobx' in:
%      'C:\Users\[your account]\AppData\Roaming\MathWorks\MATLAB\local_cluster_jobs\R20xxx\'.
%      The setting files in these folders may not allow you to connect to the parallel pool,
%      which is used in this function. Tailor your data then, to avoid this problem.

% -------------------- parse inputs --------------------
mIp = inputParser;
mIp.addRequired("trialsData");
mIp.addRequired("fs", @(x) validateattributes(x, {'numeric'}, {'scalar', 'positive'}));
mIp.addOptional("segNum", 10, @(x) validateattributes(x, {'numeric'}, {'scalar', 'positive', 'integer'}));
mIp.addParameter("mode", "auto", @mu.isTextScalar);
mIp.addParameter("outType", "raw", @mu.isTextScalar);
mIp.addParameter("tPad", [], @(x) validateattributes(x, {'numeric'}, {'scalar', 'positive'}));
mIp.addParameter("wavelet", "amor", @mu.isTextScalar);
mIp.parse(trialsData, fs, varargin{:});

segNum   = mIp.Results.segNum;
workMode = validatestring(mIp.Results.mode, {'auto', 'CPU', 'GPU'});
outType  = validatestring(mIp.Results.outType, {'raw', 'power', 'phase', 'freq'});
tPad     = mIp.Results.tPad; % total duration of padding (sec)
wname    = char(validatestring(mIp.Results.wavelet, {'amor', 'morse', 'bump'}));

% -------------------- prepare data --------------------
switch class(trialsData)
    case "cell"
        trialsData = trialsData(:);
        nTrial = numel(trialsData);
        [nCh, nTime0] = mu.checkdata(trialsData);
        trialsData = cat(1, trialsData{:});         % (nTrial*nCh) x nTime0
    case "double"
        nTrial = 1;
        [nCh, nTime0] = size(trialsData);
    otherwise
        error("Invalid data type");
end

nTotal = nTrial * nCh;

if segNum > nTotal
    disp(['Segment numebr > nCh*nTrial, set segNum = ', num2str(nTotal)]);
    segNum = nTotal;
end

% -------------------- padding (optional) --------------------
if ~isempty(tPad)
    if tPad <= nTime0 / fs
        error("Total duration of padding should not be shorter than data duration.");
    end
    nPad  = ceil((tPad * fs - nTime0) / 2);  % one side
    nTime = nTime0 + 2 * nPad;

    % Do padding once on the big matrix (faster than per-block cellfun)
    trialsData = wextend(2, 'zpd', trialsData, [0, nPad]); % extend along dim-2
else
    nPad  = 0;
    nTime = nTime0;
end

% -------------------- probe frequency axis --------------------
t1 = tic;
[~, f, coi] = cwtMulti_np(trialsData(1, :)', fs, wname);
nFreq = numel(f);
disp(['Frequencies range from ', num2str(min(f)), ' to ', num2str(max(f)), ' Hz']);

if strcmp(outType, 'freq')
    cwtres = [];
    coi = [];
    return;
end

% -------------------- non-parallel override --------------------
if segNum == 1
    disp("Work in non-parallel mode");
    disp("Using CPU...");
    X = trialsData.';                                 % nTime x (nTotal)
    cwtres = cwtMulti_np(X, fs, wname);               % nTotal x nFreq x nTime
else
    disp("Work in parallel mode");

    % ---- decide GPU/CPU in auto mode ----
    mexName = ['cwtMulti_', wname, num2str(nTime), 'x', num2str(segNum), '_mex.mexw64'];
    hasGPU  = (gpuDeviceCount >= 1);
    if strcmpi(workMode, "auto")
        if exist(mexName, 'file') && hasGPU
            workMode = "GPU";
            disp("Using GPU...");
        else
            workMode = "CPU";
            warning("MEX file is missing or GPU device is unavailable");
            disp("Using CPU...");
        end
    elseif strcmpi(workMode, "CPU")
        disp("Using CPU...");
    elseif strcmpi(workMode, "GPU")
        disp("Using GPU...");
    else
        error("Invalid mode");
    end

    % ---- memory-based segNum adaptation (GPU/CPU) ----
    % Estimate peak per-block footprint:
    %   input block:  nTime x segNum double  -> 8*nTime*segNum bytes
    %   output block: segNum x nFreq x nTime complex double -> 16*segNum*nFreq*nTime bytes
    % Safety factor accounts for temporaries/overheads.
    bytesPerSeg_in  = 8  * nTime;
    bytesPerSeg_out = 16 * nFreq * nTime;
    safetyFactor    = 1.45;

    if strcmpi(workMode, "GPU")
        [segNumNew, msg] = local_adaptSegNum(segNum, nTotal, bytesPerSeg_in, bytesPerSeg_out, safetyFactor, "gpu");
        if segNumNew ~= segNum
            disp(msg);
            segNum = segNumNew;
        end
    else
        [segNumNew, msg] = local_adaptSegNum(segNum, nTotal, bytesPerSeg_in, bytesPerSeg_out, safetyFactor, "cpu");
        if segNumNew ~= segNum
            disp(msg);
            segNum = segNumNew;
        end
    end

    if segNum == 1
        % If memory forced segNum -> 1, behave like non-parallel CPU mode.
        disp("Memory check forced segNum=1; switching to non-parallel CPU path.");
        X = trialsData.';                                 % nTime x (nTotal)
        cwtres = cwtMulti_np(X, fs, wname);               % nTotal x nFreq x nTime
    else
        % ---- (re)build blocks ----
        nBlocks = ceil(nTotal / segNum);
        segIdx  = repmat(segNum, nBlocks, 1);
        segIdx(end) = nTotal - sum(segIdx(1:end-1));

        % Preallocate final output and fill by indices (avoids cellfun+cat)
        cwtres = complex(zeros(nTotal, nFreq, nTime, 'double'));
        starts = cumsum([1; segIdx(1:end-1)]);
        ends   = starts + segIdx - 1;

        % ---- ensure GPU mex exists if requested ----
        if strcmpi(workMode, "GPU")
            mexName = ['cwtMulti_', wname, num2str(nTime), 'x', num2str(segNum), '_mex.mexw64'];
            if ~exist(mexName, 'file')
                disp("MEX file is missing. Generating MEX file...");
                currentPath = pwd;
                cd(fullfile(fileparts(mfilename("fullpath")), "private"));
                ft_removepaths;
                cfg = coder.gpuConfig('mex');
                str = ['codegen cwtMulti_', wname, ' -config cfg -args {coder.typeof(gpuArray(0),[', ...
                    num2str(nTime), ' ', num2str(segNum), ']),coder.typeof(0)}'];
                eval(str);
                movefile(['cwtMulti_', wname, '_mex.mexw64'], mexName);
                cd(currentPath);
                ft_defaults;
            end
        end

        cwtFcnCPU = eval(['@cwtMulti_', wname]);

        if strcmpi(workMode, "CPU")
            % Use parfor only if a pool already exists (avoid surprise pool start)
            try
                usePar = license('test','Distrib_Computing_Toolbox') && ~isempty(gcp('nocreate'));
            catch
                usePar = false;
            end

            if usePar
                for b = 1:nBlocks
                    idx1 = starts(b); idx2 = ends(b);
                    Xb = trialsData(idx1:idx2, :).';      % nTime x segThis
                    Yb = cwtFcnCPU(Xb, fs);               % segThis x nFreq x nTime
                    cwtres(idx1:idx2, :, :) = Yb;
                end
            else
                for b = 1:nBlocks
                    idx1 = starts(b); idx2 = ends(b);
                    Xb = trialsData(idx1:idx2, :).';      % nTime x segThis
                    Yb = cwtFcnCPU(Xb, fs);               % segThis x nFreq x nTime
                    cwtres(idx1:idx2, :, :) = Yb;
                end
            end

        else
            % GPU: compute full blocks with mex; tail (if any) falls back to CPU
            cwtFcnGPU = eval(['@cwtMulti_', wname, num2str(nTime), 'x', num2str(segNum), '_mex']);

            for b = 1:nBlocks
                idx1 = starts(b); idx2 = ends(b);
                segThis = idx2 - idx1 + 1;

                Xb = trialsData(idx1:idx2, :).';          % nTime x segThis

                if segThis == segNum
                    % full block on GPU
                    Yb = cwtFcnGPU(Xb, fs);
                    cwtres(idx1:idx2, :, :) = gather(Yb);
                else
                    % tail block: CPU fallback (mex signature fixed to segNum)
                    disp("Computing the tail block using CPU...");
                    Yb = cwtFcnCPU(Xb, fs);
                    cwtres(idx1:idx2, :, :) = Yb;
                end
            end
        end
    end
end

% -------------------- reshape to [nTrial x nCh x nFreq x nTime] --------------------
cwtres = reshape(cwtres, [nCh, nTrial, nFreq, nTime]);
cwtres = permute(cwtres, [2, 1, 3, 4]);

% -------------------- unpad (optional) --------------------
if nPad > 0
    cwtres = cwtres(:, :, :, nPad + 1 : nPad + nTime0);
    coi    = coi(nPad + 1 : nPad + nTime0);
end

% -------------------- output type --------------------
switch outType
    case "raw"
        % do nothing
    case "power"
        cwtres = abs(cwtres);
    case "phase"
        cwtres = angle(cwtres);
end

disp(['Wavelet transform computation done in ', num2str(toc(t1)), ' sec.']);

return;


% ========================= local helpers =========================
function [segNumNew, msg] = local_adaptSegNum(segNum0, nTotal0, bytesPerSeg_in0, bytesPerSeg_out0, safety0, which)
    segNumNew = min(segNum0, nTotal0);
    avail = local_availableMemoryBytes(which);

    % If unknown, be conservative but do not change segNum.
    if ~isfinite(avail) || avail <= 0
        msg = sprintf("Memory check: %s available memory unknown; keep segNum=%d.", upper(which), segNumNew);
        return;
    end

    target = 0.70 * avail; % leave headroom

    bytesPerSeg = safety0 * (bytesPerSeg_in0 + bytesPerSeg_out0);

    maxSeg = floor(target / bytesPerSeg);
    maxSeg = max(1, min(maxSeg, nTotal0));

    if maxSeg < segNumNew
        segNumNew = maxSeg;
        msg = sprintf("Memory check (%s): reducing segNum to %d to fit available memory.", upper(which), segNumNew);
    else
        msg = sprintf("Memory check (%s): segNum=%d fits available memory.", upper(which), segNumNew);
    end
end

function avail = local_availableMemoryBytes(which)
    avail = NaN;

    if strcmpi(which, "gpu")
        try
            g = gpuDevice();
            avail = double(g.AvailableMemory);
            return;
        catch
            avail = NaN;
            return;
        end
    end

    % CPU
    % Prefer MATLAB's memory() on Windows; otherwise use feature('memstats') if available.
    try
        if ispc
            m = memory;
            avail = double(m.MemAvailableAllArrays);
            return;
        end
    catch
        % fallthrough
    end

    try
        ms = feature('memstats'); % may vary across versions/platforms
        if isstruct(ms)
            % Try common field names
            fns = fieldnames(ms);
            cand = ["MemAvailableAllArrays","AvailableMemory","SystemFreeMemory","FreeMemory","MaxPossibleArrayBytes"];
            for k = 1:numel(cand)
                if any(strcmpi(fns, cand(k)))
                    avail = double(ms.(fns{strcmpi(fns, cand(k))}));
                    return;
                end
            end
        end
    catch
        % unknown
    end
end

end
