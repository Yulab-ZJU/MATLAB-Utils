function addDataTips(H, tips)
%ADDDATATIPS  Apply datacursor-based tips to any graphics objects.
%
% Inputs
%   H    : gobjects array (line / patch / scatter / mixed)
%   tips : array of matlab.graphics.datatip.DataTipTextRow
%          e.g., tips = [dataTipTextRow("Data1", data1, '%.4g'); ...
%                        dataTipTextRow("Data2", data2, '%.4g')]
%
% This function converts DataTipTextRow definitions into
% datacursormode UpdateFcn-compatible text, and attaches them
% to graphics objects via UserData.
%
% Compatible with R2025a+ and older versions.

arguments
    H    (:,1) {isgraphics}
    tips (:,1) matlab.graphics.datatip.DataTipTextRow
end

for i = 1:numel(H)
    hObj = H(i);
    if ~isgraphics(hObj), continue; end
    
    if isprop(hObj, 'DataTipTemplate')
        hObj.DataTipTemplate.DataTipRows(end + 1:end + numel(tips)) = tips;
    else
        if ~isstruct(hObj.UserData), hObj.UserData = struct(); end

        temp_tips = cell(numel(tips), 1);
        for j = 1:numel(tips)
            temp_tips{j}.Label = tips(j).Label;
            temp_tips{j}.Value = tips(j).Value;
            temp_tips{j}.Format = tips(j).Format;
        end
        hObj.UserData.mu_compat_tips = temp_tips;

        fig = ancestor(hObj, 'figure');
        dcm = datacursormode(fig);
        dcm.UpdateFcn = @compatUpdateFcn;
        dcm.Enable = 'on';
    end
end

return;
end

%% 
function txt = compatUpdateFcn(~, evt)
    h = evt.Target;
    pos = evt.Position;
    idx = evt.DataIndex;
    
    txt = {sprintf('\\bf{X}:\\rm %.4g', pos(1)); sprintf('\\bf{Y}:\\rm %.4g', pos(2))};

    if isgraphics(h) && isstruct(h.UserData) && isfield(h.UserData, 'mu_compat_tips')
        ctips = h.UserData.mu_compat_tips;
        for i = 1:numel(ctips)
            valData = ctips{i}.Value;
            lbl = ctips{i}.Label;
            fmt = ctips{i}.Format;

            if ismatrix(valData) && ~isscalar(valData)
                if numel(idx) >= 2
                    val = valData(idx(2), idx(1));
                else
                    val = valData(idx);
                end
            else
                val = valData;
            end
            
            try
                txt{end + 1} = sprintf('\\bf{%s}:\\rm %s', lbl, sprintf(fmt, val));
            catch
                txt{end + 1} = sprintf('\\bf{%s}:\\rm error', lbl);
            end
        end
    end
end