function res = mCoherenceWaveletImpl(data)
% [data] contains
%     - freq: 1*nfreq double
%     - time: 1*ntime double
%     - label: nchan*1 cellstr
%     - dimord: 'rpt_chan_freq_time'
%     - cumtapcnt: ones(length(data.time), length(data.freq))
%     - fourierspctrm: nrpt*nchan*nfreq*ntime complex double matrix, obtained by wavelet transform

%% coherence computation
[nrpt, nchan, nfreq, ntime] = size(data.fourierspctrm);

% cross density matrix
data.crsspctrm = zeros(nchan, nchan, nfreq, ntime); % chan_chan_freq_time
data.crsspctrm = pagemtimes(pagectranspose(data.fourierspctrm), data.fourierspctrm) ./ nrpt;
crsspctrm(1, :, :, :, :) = data.crsspctrm;

res = keepfields(data, {'freq', 'time'});
res.dimord = 'rpt_chan_chan_freq_time';

optarg = {'hasjack', 0, 'pownorm', 1, 'powindx', [], 'dimord', res.dimord};
res.coherencespctrm = ft_connectivity_corr(crsspctrm, optarg{:}); % chan_chan_freq_time

res = keepfields(res, {'time', 'freq', 'coherencespctrm'});

return;
end