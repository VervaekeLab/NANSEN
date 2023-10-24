function [ metadata ] = getThorlabsMetaData( dataFolderPath )
%getThorlabsMetaData Load fields from a thorlabs XML file into a matlab struct.
%   M = getThorlabsMetaData(tSeriesPATH) returns a struct with metadata (M) from a 
%   recording specified by folderPath, where folderPath is the path to a recording folder.
%
%   Returned Fields:
%       - microscope     :   Thorlabs
%       - frameRate      :   framerate of recording
%       - pixelX         :   width of image in number of pixels
%       - pixelY         :   height of image in number of pixels
%       - NumberOfPlanes :   zoomfactor during the recording
%       - pixelSizeUM    :   um per pixel conversion factor
%       - channel       :   list of channels that are recorded (e.g. 1)
%       - nFrames       :   array of nFrames per block


% Todo : how to find planes

    attributes = struct('LSM', {{'NumberOfPlanes', 'channel', 'frameRate', ...
                                'pixelSizeUM', 'pixelX', 'pixelY'}}, ...
                        'Streaming', {{'frames'}} );

    % Init metadata
    metadata = struct;
    
    % open xmlfile using xmlread
    xmlFile = dir(fullfile(dataFolderPath, '*.xml'));
    keep = ~ strncmp({xmlFile.name}, '.', 1);
    xmlFile = xmlFile(keep);
    
    xmlDoc = xmlread(fullfile(dataFolderPath, xmlFile(1).name));

    metadata.microscope = 'Thorlabs';
    
    elementNames = fieldnames(attributes);

    for i = 1:numel(elementNames)
        xmlElements = xmlDoc.getElementsByTagName(elementNames{i});
        elementItem = xmlElements.item(0);
        
        attributeNames = attributes.(elementNames{i});

        for j = 1:numel(attributeNames)
            thisAttributeValue = elementItem.getAttribute(attributeNames{j});
            metadata.(attributeNames{j}) = str2double(thisAttributeValue);
        end
    end
    
    % Example parsing all attributes:
    % xmlElements = xmlDoc.getElementsByTagName('Streaming');
    % item = xmlElements.item(0);
    % attributes = parseAttributes(item);
end

function attributes = parseAttributes(xmlItem)

    % Example parsing all the attributes:
    xmlAttributes = xmlItem.getAttributes();

    attributes = struct();
    numAttributes = xmlAttributes.getLength();

    for count = 1:numAttributes
        thisAttribute = xmlAttributes.item(count-1);
        thisAttributeName = char(thisAttribute.getName);
        thisAttributeValue = char(thisAttribute.getValue);
        attributes.(thisAttributeName) = thisAttributeValue;
    end
end

