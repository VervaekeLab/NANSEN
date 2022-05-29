function mat2tiffstack( mat, stackPath, createRgb)
%mat2tiffstack writes an uint8 array to a tiff-stack
%
%   mat2tiffstack(A, filepath) saves 3D array as a tiff stack in 
%       specified path

% Todo: implement stack order...
% Note: only works for 3D stack or 4D RGB stack

if nargin < 3; createRgb = false; end

nDim = numel(size(mat));
className = class(mat);

switch className
    case 'uint8'
        bitsPerSample = 8;
    case 'uint16'
        bitsPerSample = 16;
    case {'uint32', 'single'}
        bitsPerSample = 32;
    case 'double'
        bitsPerSample = 64;
end


if (nDim == 2 || nDim == 3) && ~createRgb
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
        nansen.stack.utility.mat2tiffstack(mat, stackPath, false)
    else
        %assert(nColors == 3)

        tiffFile = Tiff(stackPath,'w');

        for f = 1:nFrames
            tiffFile.setTag('ImageLength', height);
            tiffFile.setTag('ImageWidth', width');
            tiffFile.setTag('Photometric',Tiff.Photometric.RGB);
            tiffFile.setTag('PlanarConfiguration',Tiff.PlanarConfiguration.Chunky);
            tiffFile.setTag('BitsPerSample', bitsPerSample);
            tiffFile.setTag('SamplesPerPixel', 3);
            tiffFile.setTag('Compression',Tiff.Compression.None);
            tiffFile.write(mat(:, :, :, f));
            tiffFile.writeDirectory();
        end
    end

    tiffFile.close();

else
    error('No implementation for %d-dimensional stacks', nDim) 
end

end
