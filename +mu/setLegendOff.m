function setLegendOff(targets)
%SETLEGENDOFF  Hide legends of targets.

for index = 1:numel(targets)
    set(get(get(targets(index), 'Annotation'), 'LegendInformation'), 'IconDisplayStyle', 'off');
end

return;
end