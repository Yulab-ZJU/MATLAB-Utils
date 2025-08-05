function chErr = calchErr(trialsData)
chErr = squeeze(mu.se(cat(3, trialsData{:}), 3, "omitnan"));
return;
end