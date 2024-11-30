function imFilepath = findrawfile(recordingFolder)
    
    [~, recName, ~] = fileparts(recordingFolder);
    L = dir(fullfile(recordingFolder, '*.raw'));
    
    if numel(L) > 1
        warning('Multiple files detected for recording "%s", selected first one...', recName)
    elseif isempty(L)
        error('No file was detected for recording "%s", recName')
    end
    
    imFilepath = fullfile(recordingFolder, L(1).name);
    
end
