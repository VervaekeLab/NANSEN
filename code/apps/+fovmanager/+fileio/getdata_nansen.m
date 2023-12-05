function S = getdata(sessionID, dataName)
% Function that loads data given a sessionID
%
%   S = fovmanager.fileio.getdata(sessionID, dataName) loads data given a sessionID.
%   dataName is a character vector or a cellarray of character vectors
%   S is a struct with names corresponding to the given dataNames.
% 
%   This function should support the following dataNames:
%       fovImage : An average image of the FoV
%       roiArray : The roi array from this fov
%       zoomFactor : zoomFactor for recording
%       fovDepth : Depth of imaging during recording
%       fovSize : Size of FoV in mm.
%
%   Example: S = fovmanager.fileio.getdata(sessionID, {'fovImage', 'fovSize'})
%       Output S will have two fields, fovImage and fovSize.
%   
%   This function is used in some parts of the fov manager to retrieve
%   necessary data from a session.

    % Note: Ideally, all of these datatypes are present in sData

    % Eivind's example code:
    
    loadPath = nansen.getCurrentProject().MetaTableCatalog.getDefaultMetaTablePath();
    metaTable = nansen.metadata.MetaTable.open(loadPath);
    
    isMatch = strcmp( metaTable.members, sessionID);
    entry = metaTable.entries(isMatch, :);    
    
    sData = getSessionData(sessionID);
    S = struct();
    
    if isa(dataName, 'char')
        dataName = {dataName};
    end
    
    for i = 1:numel(dataName)
    
        switch dataName{i}

            case 'fovImage'
                S.fovImage = sData.fovImage(2).average;
            case 'roiArray'
                S.roiArray = sData.roiArray;
            case 'zoomFactor'
                %S.zoomFactor = sData.meta2P.zoomFactor;
            case 'fovDepth'
                %S.fovDepth = sData.meta2P.zPosition;
            case 'fovSize'
                imSize = size(sData.fovImage(2).average);
                umPerPx = [sData.meta2P.umPerPxY, sData.meta2P.umPerPxX];
                S.fovSize = mean(imSize.*umPerPx)./1000;
        end
        
    end
    
end