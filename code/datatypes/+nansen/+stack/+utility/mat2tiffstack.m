function mat2tiffstack( mat, stackPath, createRgb, useBigTiff)
%mat2tiffstack writes an uint8 array to a tiff-stack
%
%   mat2tiffstack(A, filepath) saves 3D array as a tiff stack in
%       specified path

% Todo: implement stack order...
% Note: only works for 3D stack or 4D RGB stack

if nargin < 3; createRgb = false; end
if nargin < 4; useBigTiff = false; end

nDim = numel(size(mat));
className = class(mat);

switch className
    case {'uint8', 'int8'}
        bitsPerSample = 8;
    case {'uint16', 'int16'}
        bitsPerSample = 16;
    case {'uint32', 'int32'}
        bitsPerSample = 32;
    case 'single'
        bitsPerSample = 32;
    case 'double'
        bitsPerSample = 64;
    otherwise
        disp('a')
end

switch className
    case {'uint8', 'uint16', 'uint32'}
        sampleFormat = Tiff.SampleFormat.UInt;
    case {'int8', 'int16', 'int32'}
        sampleFormat = Tiff.SampleFormat.Int;
    case {'single', 'double'}
        sampleFormat = Tiff.SampleFormat.IEEEFP;
    otherwise
end

if useBigTiff
    tiffMode = 'w8';
else
    tiffMode = 'w';
end

if (nDim == 2 || nDim == 3) && ~createRgb
    [height, width, nFrames] = size(mat);

    tiffFile = Tiff(stackPath, tiffMode);

    for f = 1:nFrames
        % Todo: Should this be done for each image/IFD?
        tiffFile.setTag('ImageLength', height);
        tiffFile.setTag('ImageWidth', width);
        tiffFile.setTag('Photometric',Tiff.Photometric.MinIsBlack);
        tiffFile.setTag('PlanarConfiguration',Tiff.PlanarConfiguration.Chunky);
        tiffFile.setTag('BitsPerSample', bitsPerSample);
        tiffFile.setTag('SamplesPerPixel', 1);
        tiffFile.setTag('SampleFormat', sampleFormat);
        tiffFile.setTag('Compression',Tiff.Compression.None);
        tiffFile.write(mat(:, :, f));

        if f < nFrames
            tiffFile.writeDirectory();
        end
    end
    tiffFile.close();

elseif nDim == 4 || createRgb
    
    [height, width, nColors, nFrames] = size(mat);

    if nColors ~= 3
        % Write as interleaved 3D stack instead
        mat = reshape(mat, height, width, []);
        nansen.stack.utility.mat2tiffstack(mat, stackPath, false, tiffMode)
    else
        %assert(nColors == 3)

        tiffFile = Tiff(stackPath, tiffMode);

        for f = 1:nFrames
            tiffFile.setTag('ImageLength', height);
            tiffFile.setTag('ImageWidth', width');
            tiffFile.setTag('Photometric',Tiff.Photometric.RGB);
            tiffFile.setTag('PlanarConfiguration',Tiff.PlanarConfiguration.Chunky);
            tiffFile.setTag('BitsPerSample', bitsPerSample);
            tiffFile.setTag('SamplesPerPixel', 3);
            tiffFile.setTag('SampleFormat', sampleFormat);
            tiffFile.setTag('Compression',Tiff.Compression.None);
            tiffFile.write(mat(:, :, :, f));
            tiffFile.writeDirectory();
        end
        
        tiffFile.close();
    end

else
    [height, width, nFrames] = size(mat);

    mat = reshape(mat, height, width, []);
    nansen.stack.utility.mat2tiffstack(mat, stackPath, false, tiffMode)
    %error('No implementation for %d-dimensional stacks', nDim)
end
end
