function [ metadata ] = getPrairieMetaData( tSeriesPath, metadata )
%getPrairieMetaData Load fields from a prairie view XML file into a matlab struct.
%   M = getPrairieMetaData(tSeriesPATH) returns a struct with metadata (M) from a 
%   recording specified by tSeriesPATH, where tSeriesPATH is the path to a tSeries Folder.
%
%   M = getPrairieMetaData(PATH, M) updates a metadata (M) file by concatenating info 
%   to some of the output fields (nBlocks, nFrames, times) for each block/cycle of a session.
%
%   The idea of this function is to get metadata either from one recording
%   or from multiple blocks of recordings. By looping through a set of
%   "blockfolders" and passing the metadata from the previous iteration to
%   this function, the following fields are updated with data from the most
%   recent block: nBlocks, nFrames, times.
%   All other fields are assumed constant throughout a block recording and
%   is only retrieved from the first of multiple blocks of recordings
%
%   Returned Fields:
%       - microscope    :   Prairie
%       - dt            :   interframe interval
%       - xpixels       :   width of image in pixels
%       - ypixels       :   height of image in pixels
%       - objective     :   not necessary for now (not added)
%       - zoomFactor    :   zoomfactor during the recording
%       - pmtCh2        :   Voltage gain on PMT2
%       - pmtCh3        :   Voltage gain on PMT3
%       - zPosition     :   relative z position of microscope during data acquistion
%       - umPerPx_x     :   um per pixel conversion factor along x axis
%       - umPerPx_y     :   um per pixel conversion factor along y axis
%       - nCh           :   number of channels acquired
%       - channels      :   list of channels that are recorded (e.g. [2, 3])
%       - channelNames  :   list of corresponding channel names e.g. {Ch2, Ch3}
%       - channelColor  :   list of corresponding color for each channel e.g. {green, red}
%       - nBlocks       :   number of blocks (incremented every time metadata is updated)
%       - nFrames       :   array of nFrames per block
%       - times         :   array of time vectors per recording per block
%
%       see also loadPrairieViewStack

% Todo : how to find planes
    

% Init metadata
if nargin < 2
    metadata = struct;
end

% open xmlfile using xmlread
xmlFile = dir(fullfile(tSeriesPath, '*.xml'));
keep = ~ strncmp({xmlFile.name}, '.', 1);
xmlFile = xmlFile(keep);

xmlDoc = xmlread(fullfile(tSeriesPath, xmlFile(1).name));

% start filling up fields of metadata
if isempty(fieldnames(metadata))
    
    metadata.microscope = 'Prairie';
    
    PvStateItems = xmlDoc.getElementsByTagName('PVStateValue');

    for i = 1:PvStateItems.getLength()
        key = char(PvStateItems.item(i-1).getAttribute('key'));

        switch key

            case 'bitDepth'
                bitDepth = PvStateItems.item(i-1).getAttribute('value');
                metadata.bitDepth = str2double(bitDepth);
                
            case 'framePeriod'
                framePeriod = PvStateItems.item(i-1).getAttribute('value');
                metadata.dt = str2double(framePeriod);

            case 'objectiveLens'
                objectiveLens = PvStateItems.item(i-1).getAttribute('value');
                metadata.objective = char(objectiveLens);

            case 'opticalZoom'
                 opticalZoom = PvStateItems.item(i-1).getAttribute('value');
                 metadata.zoomFactor = str2double(opticalZoom);

            case 'linesPerFrame'
                linesPerFrame = PvStateItems.item(i-1).getAttribute('value');
                metadata.ypixels = str2double(linesPerFrame);

            case 'pixelsPerLine'
                pixelsPerLine = PvStateItems.item(i-1).getAttribute('value');
                metadata.xpixels = str2double(pixelsPerLine);

            case 'pmtGain'
                pmtGainItems = PvStateItems.item(i-1).getElementsByTagName('IndexedValue');
                pmt2 = pmtGainItems.item(1).getAttribute('value');
                %pmt3 = pmtGainItems.item(2).getAttribute('value');
                metadata.pmtCh2 = str2double(pmt2);
                %metadata.pmtCh3 = str2double(pmt3);

            case 'positionCurrent'
                posAxisItems = PvStateItems.item(i-1).getElementsByTagName('SubindexedValues');
                xPosItems = posAxisItems.item(0).getElementsByTagName('SubindexedValue');
                yPosItems = posAxisItems.item(1).getElementsByTagName('SubindexedValue');
                zPosItems = posAxisItems.item(2).getElementsByTagName('SubindexedValue');
                currentXpos = xPosItems.item(0).getAttribute('value');
                currentYpos = yPosItems.item(0).getAttribute('value');
                currentZpos = zPosItems.item(0).getAttribute('value');
                metadata.xPosition = str2double(currentXpos);
                metadata.yPosition = str2double(currentYpos);
                metadata.zPosition = str2double(currentZpos);

            case 'micronsPerPixel'
                items = PvStateItems.item(i-1).getElementsByTagName('IndexedValue');
                metadata.umPerPx_x = str2double( items.item(0).getAttribute('value') );
                metadata.umPerPx_y = str2double( items.item(1).getAttribute('value') );
                metadata.umPerPx_z = str2double( items.item(2).getAttribute('value') );

        end
    end

    % Calculate microns per pixel
    if strcmp(objectiveLens, 'Nikon 16x')
        %metadata.umPerPx_x = 860 / metadata.zoomFactor / metadata.xpixels; % max FOV = 860 um.
        %metadata.umPerPx_y = 860 / metadata.zoomFactor / metadata.ypixels; % max FOV = 860 um.
        % /todo: what if user is scanning less lines? are nlines still
        % equal to resolution setting?
    else
        %error('Unknown objective, please resolve')
    end
    
    metadata.nPlanes = 1; % Todo
    
    % Set metadata.nBlocks to 0 and metadata.nFrames to empty array
    metadata.nBlocks = 0;
    metadata.nFrames = [];
    % Set metadata.times to empty cell
    metadata.times = {};
end

% Find number of cycles/blocks
sequenceItems = xmlDoc.getElementsByTagName('Sequence');
nSequences = sequenceItems.getLength();

for s = 1:nSequences
    frameItems = sequenceItems.item(s-1).getElementsByTagName('Frame');
    nFrames = frameItems.getLength();
    
    if nFrames ~= 0
        metadata.nBlocks = metadata.nBlocks + 1; % update number of blocks
        metadata.nFrames(end+1) = nFrames; % update number of frames in block
    
        % Retrieve channel info from the first frame
        chItems = frameItems.item(0).getElementsByTagName('File');
        metadata.nCh = chItems.getLength();
        metadata.channels = zeros(metadata.nCh , 1);        % channelnumbers. e.g. [2, 3]
        metadata.channelNames = cell(metadata.nCh , 1);     % channelNames e.g. {Ch2, Ch3}
        metadata.channelColor = cell(metadata.nCh , 1);     % channelColor e.g. {green, red}
        colors = {'yellow', 'green', 'red', 'blue'};
        for c = 1:metadata.nCh
            metadata.channels(c) = str2double(chItems.item(c-1).getAttribute('channel'));
            metadata.channelNames{c} = char(chItems.item(c-1).getAttribute('channelName'));
            metadata.channelColor{c} = colors{metadata.channels(c)};
        end
    
        % Retrieve frame times
        times = zeros(nFrames, 1);
        for f = 1:nFrames
            t = frameItems.item(f-1).getAttribute('relativeTime');
            times(f) = str2double(t);
        end
        metadata.times{end+1} = times; % update frametimes
    end
    
end

end

