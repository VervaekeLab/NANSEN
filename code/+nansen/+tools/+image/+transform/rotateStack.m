function [ imStack ] = rotateStack( imStack, angles, crop, printmsg, method)
%RotateStack rotates images of a stack according to a vector of angles
%   [ IMSTACK ] = rotateStack( IMSTACK, ANGLES) rotates all images of
%   IMSTACK according to angles in ANGLES. Number of images and angles must
%   be the same. Returns rotated version of IMSTACK, in same dimensions,
%   eg. images are rotated and cropped to yield same size as input.
%
%   [ IMSTACK ] = rotateStack( IMSTACK, ANGLES, CROP) rotates images
%   without cropping them if CROP is true. Output images are larger than 
%   inputs.
%
%   [ IMSTACK ] = rotateStack( IMSTACK, ANGLES, CROP, PRINTMSG) rotates 
%   images and writes progress to the commandline if PRINTMSG is true.

%   Written by Eivind Hennestad | Vervaeke Lab

prevstr=[];

% Use default values if the last two inputs are missing.
if nargin < 5;  method = 'bicubic';
if nargin < 4;  printmsg = false;   end
if nargin < 3;  crop = 1;   end

% Get stack dimensions and length of vector with angles
[nRows, nCols, nFrames] = size(imStack);
nAngles = length(angles);

% Assert that length of imagestack and length of anglevector are the same
assert(nFrames == nAngles, 'Length of inputs do not match');

% Make array to hold rotated images if images are rotated without cropping
if ~crop
    testIm = zeros(nRows, nCols);
    testIm = imrotate(testIm, 45);
    new_size = size(testIm)+1;
    
    % Need this to work for boolean arrays as well
    switch class(imStack)
        case 'logical'
            newStack = zeros(new_size(1), new_size(2), nFrames, 'uint8');
        otherwise
            newStack = zeros(new_size(1), new_size(2), nFrames, 'like', imStack);
    end
end    


% Loop through images and rotate
for n = 1:nFrames
    
    angle = angles(n);
    
    if crop
        imStack(:, :, n) = imrotate(imStack(:, :, n), angle, method, 'crop');
    else
        im = imrotate(imStack(:, :, n), angle, method);
        tmp_size = size(im);
        shift = floor((new_size - tmp_size) ./ 2);
        newStack(shift(1) + (1 : tmp_size(1)), ...
           shift(2) + (1 : tmp_size(2)), n) = im; % put im in cntr...

    end
    
    if mod(n,100) == 0 && printmsg
        str=['rotating frame ' num2str(n) '/' num2str(nFrames)];
        refreshdisp(str, prevstr, n);
        prevstr=str;
    end
    
end

if ~crop
    imStack = newStack;
else
    imStack = imStack(:, :, 1:nFrames);
end  

if printmsg
    fprintf(char(8*ones(1,length(prevstr))));
    fprintf('Rotated all images.');
    fprintf('\n');
end

end

