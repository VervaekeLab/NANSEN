function requiredToolboxes = getRequiredMatlabToolboxes()
%getRequirements - Get required MATLAB Toolboxes
    filePath = fullfile(nansen.rootpath, 'code', 'resources', 'requirements.txt');
    requiredToolboxes = strsplit( fileread(filePath), newline);
    requiredToolboxes = requiredToolboxes(cellfun(@(c) ~isempty(c), requiredToolboxes));
end