function [trialAll, ITI] = noiseProcessFcn(epocs)
    onset = epocs.Swep.onset * 1000; % ms
    trialAll = struct("trialNum", num2cell((1:length(onset))'), ...
                      "onset", num2cell(onset(:)));
    ITI = unique(roundn(diff(onset), 0));
    return;
end