function dff = extractDff(imArray, roiArray, method, hWaitbar)

    error('Deprecated') % Todo: remove
    
    % if nargin < 3; method = 'standard'; end
    % if nargin < 4; hWaitbar = []; end
    % 
    % % Get the roimanager as a local package (2 folders up)
    % rootPath = fileparts(fileparts(fileparts(mfilename('fullpath'))));
    % roitools = tools.path2module(rootPath);
    % 
    % imageMask = mean(imArray, 3)~=0;
    % signalArray = roitools.extractSignalFromImageData(imArray, roiArray, method, [], imageMask, [], hWaitbar);
    % 
    % fRoi = squeeze(signalArray(:, 1, :))';
    % 
    % if ~strcmp(method, 'raw') && ~strcmp(method, 'unique roi')
    %     % compute neuropil fluorescence
    %     fPil = squeeze(signalArray(:, 2, :))';
    %     dff = roitools.dffRoiMinusDffNpil(fRoi', fPil')';
    % else
    %     fRoi0 = prctile(fRoi, 20, 2);
    %     dff = (fRoi - fRoi0) ./ fRoi0;
    % end
end
