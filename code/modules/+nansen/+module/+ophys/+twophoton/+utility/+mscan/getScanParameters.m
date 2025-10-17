function metadata = getScanParameters( fileReference )
%getScanParameters Get scan parameters for a MDF file from sutter

% Modified from MDF_file_reader @ flow_registration by Philipp Flotho.

%%  Get MCSX File object
    if ismac
        error('Sutter MDF files can not be read from macOS')
    end

    if ischar(fileReference)
        mfileObj = actxserver('MCSX.Data',[0 0 0 0]);
        if mfileObj.invoke('OpenMCSFile', fileReference)
            error('Only one MDF file instance can be opened at once! E.g. close the MDF Viewer and clear the Matlab workspace.');
        end

    elseif isa( fileReference, 'COM.MCSX_Data' )
        mfileObj = fileReference;
    else
        error('Wrong input')
    end
    
%% Read metadata
    S = struct;

    % Frame and stack size
    S.FrameHeight = str2double( mfileObj.ReadParameter('Frame Height') );
    S.FrameWidth = str2double( mfileObj.ReadParameter('Frame Width') );
    S.FrameCount = str2double( mfileObj.ReadParameter('Frame Count') );

    % Count available channels
    channelInd = [];
    for i = 0:2
        channelParameterName = sprintf('Scanning Ch %d Name', i);
        if ~isempty( mfileObj.ReadParameter(channelParameterName) )
            channelInd(end+1) = i + 1; %#ok<AGROW>
        end
    end
    S.ChannelInd = channelInd;
    S.NumChannels = numel(channelInd);

    % Get number of planes
    S.NumPlanes = str2double( mfileObj.ReadParameter('Section Count') );

    % Get bit depth (Always unsigned?)
    bitDepth = mfileObj.ReadParameter('Frame Bit Depth');
    S.BitDepth = stringWithUnitToNumber(bitDepth, '-bit');
    S.DataType = sprintf('uint%d', ceil(S.BitDepth / 8) .* 8);

    % Physical units
    micronsPerPixel = mfileObj.ReadParameter('Microns per Pixel');
    S.MicronsPerPixel = stringWithUnitToNumber(micronsPerPixel, 'µm');
    
    frameDuration = mfileObj.ReadParameter('Frame Duration (s)');
    S.FrameDuration = stringWithUnitToNumber(frameDuration, 's');
    S.FrameDurationUnit = 's';

    frameInterval = mfileObj.ReadParameter('Frame Interval (ms)');
    S.FrameInterval = stringWithUnitToNumber(frameInterval, 'ms');
    S.FrameIntervalUnit = 'ms';
    
    magnification = mfileObj.ReadParameter('Magnification');
    S.Magnification = stringWithUnitToNumber(magnification, 'x');

    % Physical position
    xPositionStr = mfileObj.ReadParameter('X Position');
    S.XPosition = stringWithUnitToNumber(xPositionStr, 'µm');
    S.XPositionUnit = 'µm';

    yPositionStr = mfileObj.ReadParameter('Y Position');
    S.YPosition = stringWithUnitToNumber(yPositionStr, 'µm');
    S.YPositionUnit = 'µm';

    zPositionStr = mfileObj.ReadParameter('Z Position');
    S.ZPosition = stringWithUnitToNumber(zPositionStr, 'µm');
    S.ZPositionUnit = 'µm';

    % Handle potentially missing values
    if isempty(S.MicronsPerPixel) || isnan(S.MicronsPerPixel)
        S.MicronsPerPixel = 1;
        warning('Microns per pixel could not be read from mdf');
    end

    if isempty(S.Magnification)
        S.Magnification = 1;
        warning('Magnification could not be read from mdf');
    end
    
    % Update frame duration
    if isempty(S.FrameDuration) || isempty(S.FrameInterval)
        S.FrameDuration = 1 / 30.91;
        warning('Frame duration and frame interval could not be read from mdf');
    else
        S.FrameDuration = S.FrameDuration + S.FrameInterval.*1000;
    end
    
    metadata = S;
end

function num = stringWithUnitToNumber(str, unit)
    
    % Replace commas with dots
    str = strrep(str, ',', '.');

    % Remove unit
    str = strrep(str, unit, '');
    
    % Convert string to number
    num = str2double(str);

end
