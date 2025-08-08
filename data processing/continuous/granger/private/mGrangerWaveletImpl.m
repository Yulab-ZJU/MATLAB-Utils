function res = mGrangerWaveletImpl(data)
% [data] contains
%     - freq: 1*nfreq double
%     - time: 1*ntime double
%     - label: nchan*1 cellstr
%     - dimord: 'rpt_chan_freq_time'
%     - cumtapcnt: ones(length(data.time), length(data.freq))
%     - fourierspctrm: nrpt*nchan*nfreq*ntime complex double matrix, obtained by wavelet transform
% [res] contains
%     - grangerspctrm: nchannelcmb*nfreq*ntime double, nchannelcmb=2*(nchan-1)
%     - freq
%     - time
%     - channelcmb: nchannelcmb*2 cell
%                 e.g.
%                 {'seed'} -> {'1'   }
%                 {'1'   } -> {'seed'}
%                 {'seed'} -> {'2'   }
%                 {'2'   } -> {'seed'}
%                 ...

%% Parameter settings
Niterations = 100;
tol = 1e-18;
checkflag = true;
stabilityfix = true;

%% granger causality computation
cfg = [];
cfg.channelcmb = cat(2, cellstr(repmat(data.label{1}, [length(data.label(2:end)), 1])), data.label(2:end));
cfg.cmbindx = [ones(size(cfg.channelcmb, 1), 1), (2:size(cfg.channelcmb, 1) + 1)'];

[nrpt, nchan, nfreq, ntime] = size(data.fourierspctrm);

% cross density matrix
data.crsspctrm = zeros(nchan, nchan, nfreq, ntime); % chan_chan_freq_time
data.crsspctrm = pagemtimes(pagectranspose(data.fourierspctrm), data.fourierspctrm) ./ nrpt;

[Htmp, Ztmp, Stmp] = sfactorization_wilson2x2_new(data.crsspctrm, ...
                                                  data.freq, ...
                                                  Niterations, ...
                                                  tol, ...
                                                  cfg.cmbindx, ...
                                                  checkflag, ...
                                                  stabilityfix);

res = keepfields(data, {'freq', 'time'});
res.crsspctrm(1, :, :, :) = Stmp;
res.transfer (1, :, :, :) = Htmp;
res.noisecov (1, :, :, :) = Ztmp;
res.dimord = 'rpt_chancmb_freq_time';

optarg = {'hasjack', 0, 'method', 'granger', 'powindx', [], 'dimord', res.dimord};
datout = ft_connectivity_granger(res.transfer, ...
                                 res.noisecov, ...
                                 res.crsspctrm, ...
                                 optarg{:});

% grangerspctrm follows:
%     grangerspctrm(:, (k-1) * 4 + 1, :, :, :) -> 'chan1->chan1'
%     grangerspctrm(:, (k-1) * 4 + 2, :, :, :) -> 'chan1->chan2' 
%     grangerspctrm(:, (k-1) * 4 + 3, :, :, :) -> 'chan2->chan1'
%     grangerspctrm(:, (k-1) * 4 + 4, :, :, :) -> 'chan2->chan2'

% only keep between-channel data
keepchn = 1:size(datout, 1);
keepchn = mod(keepchn, 4) == 2 | mod(keepchn, 4) == 3;
res.grangerspctrm = datout(keepchn, :, :, :, :);

channelcmb = cell(size(cfg.cmbindx, 1) * 2, 2); % [from, to]
for index = 1:size(cfg.cmbindx, 1)
    channelcmb{2 * index - 1, 1} = 'seed';
    channelcmb{2 * index - 1, 2} = num2str(index);

    channelcmb{2 * index, 1}     = num2str(index);
    channelcmb{2 * index, 2}     = 'seed';
end

res.channelcmb = channelcmb;
res = keepfields(res, {'time', 'freq', 'grangerspctrm', 'channelcmb'});

return;
end