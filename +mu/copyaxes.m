function obj = copyaxes(sourceAx, targetAx)
%COPYAXES Copy the content of one axes to the other
targetFigure = get(targetAx, "Parent");
obj = copyobj(sourceAx, targetFigure);
set(obj, "Position", get(targetAx, "Position"));
delete(targetAx);
end