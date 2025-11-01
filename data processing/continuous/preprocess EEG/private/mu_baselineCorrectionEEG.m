function trialsData = mu_baselineCorrectionEEG(trialsData, fs, windowData, windowBase)
tBaseIdx = floor((windowBase(1) - windowData(1)) * fs / 1000) + 1:floor((windowBase(2) - windowData(1)) * fs / 1000);
trialsData = cellfun(@(x) x - mean(x(:, tBaseIdx), 2), trialsData, "UniformOutput", false);
return;
end