function imArrayOut = imexpand(imArrayIn, newSize, padValue)
%imexpand Expand the image canvas of image or image stack around center
%   imArrayOut = imexpand(imArrayIn, newSize) pad image array with zeros.
%   Original array will stay in center.
%
%   imArrayOut = imexpand(imArrayIn, newSize, padValue) use another value
%   for padding. Currently available: 'zeros' or 'nan'
%
%   See also: padarray

%   Written by Eivind Hennestad | Vervaeke Lab
%   Todo: Generalize?

if nargin < 3
    padValue = 'zeros';
end

[nRows, nCols, nFrames] = size(imArrayIn);

if isequal([nRows, nCols], newSize)
    imArrayOut = imArrayIn; return
end

% preallocate output
switch padValue
    case 'zeros'
        imArrayOut = zeros( [newSize, nFrames], 'like', imArrayIn );
    case 'nan'
        imArrayOut = nan( [newSize, nFrames] );
    otherwise
        if isnumeric(padValue)
            imArrayOut = ones( [newSize, nFrames], 'like', imArrayIn ) * padValue;
        end
end

% Determine shift to position imarray in center.
shift = floor((newSize - [nRows, nCols]) ./ 2);

% put original array in center of zeroes array
imArrayOut(shift(1) + (1:nRows), shift(2) + (1:nCols), :) = imArrayIn;

end
