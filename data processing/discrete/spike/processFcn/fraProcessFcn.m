function [trialAll, ITI] = fraProcessFcn(epocs)
    onset = epocs.Swep.onset * 1000; % ms
    freq = epocs.vair.data; % Hz
    att = epocs.var2.data; % dB

    freqUnqiue = unique(freq);
    for fIndex = 1:length(freqUnqiue)
        idx = freq == freqUnqiue(fIndex);
        att(idx) = att(idx) - min(att(idx));
    end

    att = roundn(att, 0);
    trialAll = struct("trialNum", num2cell((1:length(onset))'), ...
                      "onset", num2cell(onset(:)), ...
                      "freq", num2cell(freq), ...
                      "att", num2cell(att));
    ITI = unique(roundn(diff(onset), 0));

    return;
end