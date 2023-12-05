function requiredToolboxes = getRequiredMatlabToolboxes()
%getRequiredMatlabToolboxes - Get names of required Mathworks Toolboxes
    filePath = fullfile(nansen.toolboxdir, 'resources', 'requirements.txt');
    requiredToolboxes = strsplit( fileread(filePath), newline);
    requiredToolboxes = requiredToolboxes(cellfun(@(c) ~isempty(c), requiredToolboxes));
end