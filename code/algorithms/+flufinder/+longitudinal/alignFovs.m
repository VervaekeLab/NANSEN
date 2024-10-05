function [fovShifts, imArrayNR] = alignFovs(imArray)
%alignSessionFov Aligns reference images from session and save shifts
%
% fovShifts = alignSessionFov(listOfFilePaths) returns a struct of shifts
% per FOV. listOfFilePaths is a cell array of complete filepath to each FOV
% image.
% The first image loaded from the list of files will be the reference, and
% fovShifts will have one entry less than the number of images.
%
% See also: warpRois

% Load images. Assume they are all the same size. Can implement crop/pad
% later if necessary.

    import nansen.wrapper.normcorre.utility.rigid
    import nansen.wrapper.normcorre.utility.nonrigid
    import nansen.tools.image.resize.imcropcenter
    import nansen.tools.image.registration.findRotationOffsetsFFT
    import nansen.tools.image.transform.rotateStack

    fovShifts = struct('ShiftsRig', {}, 'ShiftsRot', {}, 'ShiftsNr', {}, ...
        'CropLR', {}, 'CropUD', {});
    
    nSessions = size(imArray, 3) - 1; % -1 because the first image will be the
    % the reference session.
    
    % if isa(imArray, 'uint16')
    %     imArray = makeuint8(imArray);
    % end
    % % imviewer(imArray);
    
    % First, do a rigid alignment of all the images to the first one.
    [~, ~, ncShifts] = rigid(imArray,imArray(:,:,1));
    
    % Get array of shifts and subtract shifts of first image. This is the ref..
    shiftsRig = fliplr(squeeze(cat(1, ncShifts.shifts)));
    shiftsRig = shiftsRig(2:end, :) - shiftsRig(1, :);
    
    imArrayRig = imArray;
    for i = 1:size(shiftsRig, 1)
        imArrayRig(:, :, i+1) = imtranslate(imArray(:,:,i+1), shiftsRig(i,:) );
    end
    
    % % imviewer(imArrayRig);
    
    % Second, do a rotation correction
    imSize = size(imArray(:,:,1));
    cropSize = floor( imSize - max(abs(shiftsRig(:)))*2 - 4 );
    
    imArrayCC = single(imcropcenter(imArrayRig, cropSize));
    
    shiftsRot = findRotationOffsetsFFT(imArrayCC, []);
    imArrayRot = rotateStack(imArrayRig, shiftsRot);
    shiftsRot = shiftsRot(2:end) - shiftsRot(1);
    % imviewer(imArrayRot);
    
    cropLR = ceil([max([shiftsRig(:,1); 1]), abs( min([shiftsRig(:,1); 0]) )]) ;
    cropUD = ceil([max([shiftsRig(:,2); 1]), abs( min([shiftsRig(:,2); 0]) )]) ;
    
    % Crop effects of rigid shifts, because these can impair the nonrigid
    imArrayCropped = imArrayRot(cropUD(1):end-cropUD(2), cropLR(1):end-cropLR(2), :);
    
    % Do non-rigid correction:
    % Try to use flowreg, otherwise use normcorre
    useNormcorre = true;
    if exist('compensate_inplace', 'file')==2
        try
            [imArrayNR, shiftsNr] = compensate_inplace(imArrayCropped(:, :, 2:end), imArrayCropped(:, :, 1));
            % Rearrange shifts to be [y, x, n, delta] where the delta dimension
            % is dy, dx and the shifts are negated.
            
            shiftsNr = permute(shiftsNr, [1,2,4,3]);
            shiftsNr = - flip(shiftsNr, 4);
            % Restore shifts to original image size
            shiftsNr = padarray(shiftsNr, [cropUD(1)-1, cropLR(1)-1], 'replicate', 'pre');
            shiftsNr = padarray(shiftsNr, [cropUD(2), cropLR(2)], 'replicate', 'post');
            useNormcorre = false;
        catch
            % Use normcorre
        end
    end

    if useNormcorre
        [imArrayNR, ~, shiftsNrStruct] = nonrigid(imArrayCropped(:, :, 2:end), imArrayCropped(:, :, 1), 'finetune');
        shiftsNr = zeros([imSize, nSessions, 2]);
        for i = 1:nSessions
            shiftsNr(:, :, i, :) = imresize(shiftsNrStruct(i).shifts, imSize);
        end
    end

    % imviewer(imArrayNR)
    % test = apply_shifts(imArrayCropped(:, :, 2:end), shiftsNr, opts);
    
    for i = 1:nSessions
        % Initialize FOV shifts.
        fovShifts(i).ShiftsRig = shiftsRig(i,:);
        fovShifts(i).ShiftsRot = shiftsRot(i);
        fovShifts(i).ShiftsNr = shiftsNr(:,:,i,:);
        fovShifts(i).CropLR = cropLR;
        fovShifts(i).CropUD = cropUD;
        fovShifts(i).NrShiftsSz = size(imArrayCropped(:, :, 1));
    end

    if nargout <= 1
        clear imArrayNR
    end
end
