function requiredToolboxes = getRequiredMatlabToolboxes()
%getRequiredMatlabToolboxes - Get names of required Mathworks Toolboxes
    filePath = fullfile(nansen.rootpath, 'code', 'resources', 'requirements.txt');
    requiredToolboxes = strsplit( fileread(filePath), newline);
    requiredToolboxes = requiredToolboxes(cellfun(@(c) ~isempty(c), requiredToolboxes));
end