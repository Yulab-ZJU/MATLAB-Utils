function [trialAll, ITI] = tciProcessFcn(epocs)
    onset = epocs.Swep.onset * 1000; % ms
    order = epocs.ordr.data;
    trialAll = struct("trialNum", num2cell((1:length(onset))'), ...
                      "onset", num2cell(onset(:)), ...
                      "order", num2cell(order(:)));
    ITI = unique(roundn(diff(onset), 0));
    return;
end