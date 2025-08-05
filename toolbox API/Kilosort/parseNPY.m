function [spikeIdx, clusterIdx, templates, spikeTemplateIdx] = parseNPY(ROOTPATH)
spikeIdx = readNPY([ROOTPATH, '\spike_times.npy']);
clusterIdx = readNPY([ROOTPATH, '\spike_clusters.npy']);
templates = readNPY([ROOTPATH, '\templates.npy']);
spikeTemplateIdx = readNPY([ROOTPATH, '\spike_templates.npy']);

return;
end