function mat2tiffstack( mat, stackPath )
%mat2tiffstack writes an uint8 array to a tiff-stack
%
%   mat2tiffstack(A, filepath) saves 3D array as a tiff stack in 
%       specified path

% Todo: implement stack order...
% Note: only works for 3D stack or 4D RGB stack


nDim = numel(size(mat));
className = class(mat);

switch className
    case 'uint8'
        bitsPerSample = 8;
        sampleFormat = Tiff.SampleFormat.UInt;
    case 'uint16'
        bitsPerSample = 16;
        sampleFormat = Tiff.SampleFormat.UInt;
    case 'uint32'
        bitsPerSample = 32;
        sampleFormat = Tiff.SampleFormat.UInt;
    case 'single'
        bitsPerSample = 32;
        sampleFormat = Tiff.SampleFormat.IEEEFP;
    case 'double'
        bitsPerSample = 64;
        sampleFormat = Tiff.SampleFormat.IEEEFP;
end


if nDim == 2 || nDim == 3
    [height, width, nFrames] = size(mat);

    tiffFile = Tiff(stackPath, 'w');

    for f = 1:nFrames
        % Todo: Should this be done for each image/IFD?
        tiffFile.setTag('ImageLength', height);
        tiffFile.setTag('ImageWidth', width');
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

elseif nDim == 4
    
    [height, width, nColors, nFrames] = size(mat);

    assert(nColors == 3)

    tiffFile = Tiff(stackPath,'w');

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

else
    error('No implementation for %d-dimensional stacks', nDim) 
end

end
