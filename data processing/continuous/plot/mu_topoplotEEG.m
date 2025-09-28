function mu_topoplotEEG(varargin)
% Call topoplot (EEGLAB) with custom parameters

if isgraphics(varargin{1}(1), "axes")
    ax = varargin{1}(1);
    varargin = varargin(2:end);
else
    ax = gca;
end

mIp = inputParser;
mIp.addRequired("ax", @(x) isgraphics(x, "axes"));
mIp.addRequired("data", @(x) validateattributes(x, 'numeric', {'vector', 'real'}));
mIp.addRequired("EEGPos", @isstruct);
mIp.addParameter("ChannelsMark", [], @(x) validateattributes(x, 'numeric', {'vector', 'integer', 'positive'}));
mIp.addParameter("MarkerSize", 15, @(x) validateattributes(x, 'numeric', {'scalar', 'positive'}));
mIp.addParameter("MarkerSize0", 4, @(x) validateattributes(x, 'numeric', {'scalar', 'nonnegative'}));
mIp.parse(ax, varargin{:})

data = mIp.Results.data;
EEGPos = mIp.Results.EEGPos;
ChannelsMark = mIp.Results.ChannelsMark;
MarkerSize0 = mIp.Results.MarkerSize0;
MarkerSize = mIp.Results.MarkerSize;

Fig = get(ax, "Parent");
fontSize = get(Fig, "DefaultAxesFontSize");
titleFontSize = get(Fig, "DefaultAxesTitleFontSize");

chs2Plot = EEGPos.channels(~ismember(EEGPos.channels, EEGPos.ignore))';

if MarkerSize0 ~= 0
    marker = [{'emarker'}, {{'o', 'k', MarkerSize0, 1}}]; % {MarkerType, Color, Size, LineWidth}
else
    marker = [{'electrodes'}, {{'off'}}];
end

if EEGPos.name == "Neuroscan64"
    params0 = [...
               {'plotchans'}, {chs2Plot}                           , ... % indices of channels to plot
               {'plotrad'  }, {0.36}                               , ... % plot radius
               {'headrad'  }, {max([EEGPos.locs(chs2Plot).radius])}, ... % head radius
               {'intrad'   }, {0.4}                                , ... % interpolate radius
               {'conv'     }, {'on'}                               , ... % plot radius just covers maximum channel radius
               {'colormap' }, {flipud(slanCM('RdYlBu'))}           , ... % colormap
               marker];
elseif EEGPos.name == "Neuracle64"
    % reset location
    EEGPos.locs = readlocs('Neuracle_chan64.loc');
    params0 = [...
               {'plotchans'}, {chs2Plot}                           , ... % indices of channels to plot
               {'plotrad'  }, {0.64}                               , ... % plot radius
               {'headrad'  }, {0.58}                               , ... % head radius
               {'intrad'   }, {0.64}                               , ... % interpolate radius
               {'conv'     }, {'on'}                               , ... % plot radius just covers maximum channel radius
               {'colormap' }, {flipud(slanCM('RdYlBu'))}           , ... % colormap
               marker];
else
    error("Unsupported configuration");
end

if ~isempty(ChannelsMark)
    params = [params0, ...
              {'emarker2'}, {{find(ismember(chs2Plot, ChannelsMark)), '.', 'k', MarkerSize, 1}}, ... % {Channels, MarkerType, Color, Size, LineWidth}
             ];
else
    params = params0;
end

% call topoplot
axes(ax); % set as current axes
topoplot(data, EEGPos.locs, params{:});

% set background white
set(findobj(ax, "Type", "Patch"), "FaceColor", "w");
set(ax.Parent, "Color", "w");

% reset fontsize
set(0, "DefaultAxesFontSize", fontSize);
set(0, "DefaultAxesTitleFontSize", titleFontSize);

return;
end