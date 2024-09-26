function Video(imageStackObj)
%VIDEO Export ImageStack to video
%   Detailed explanation goes here
    
%     if isvirtual(imageStackObj)
%         error('Export is not implemented for virtual image stacks')
%     end
    
    [folder, fileName] = fileparts(imageStackObj.FileName);
    autoFileName = fullfile(folder, [fileName, '.avi']);
    
    options = struct;
    %options.FileType = 'avi';
    %options.FileType_ = {'avi', 'mp4'}
    
    options.FrameRate = 30;
    options.Filename = autoFileName;
    options.Filename_ = 'uiputfile';
    %options.DataSelection = 'Stack subselection';
    %options.DataSelection_ = {'Stack subselection', 'Full stack'};
    options.FirstFrame = 1;
    options.NumFrames = imageStackObj.NumTimepoints;
    
    if numel(imageStackObj.CurrentPlane) > 1
        options.PlaneSelection = 'Merge planes';
        planeAlternatives = arrayfun(@(i) num2str(i), 1:imageStackObj.NumPlanes, 'uni', 0);
        options.PlaneSelection_ = [{'Merge planes'}, planeAlternatives];
    end
    
    [options, wasAborted] = tools.editStruct(options);
    if wasAborted; return; end
    
    frameInd = options.FirstFrame + (1:options.NumFrames) - 1;
    
    if any(frameInd < 1)
        error('Nansen:ImageStack:FrameSetOutOfBounds', ...
            'Frame indices must be positive integers')
    elseif any(frameInd > imageStackObj.NumTimepoints)
        error('Nansen:ImageStack:FrameSetOutOfBounds', ...
            'Frame indices exceeds the number of timepoints in stack (%s)', ...
            imageStackObj.NumTimepoints)
    end
    
    % Todo: multiple planes
    
    imageData = imageStackObj.getFrameSet(frameInd);
    
    nansen.stack.utility.stack2movie(options.Filename, imageData, options.FrameRate)
    
end
