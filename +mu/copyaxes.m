function copyaxes(source, target)
%COPYAXES Copy the content of one axes to the other
targetFigure = get(target, "Parent");
obj = copyobj(source, targetFigure);
set(obj, "Position", get(target, "Position"));
delete(target);
end