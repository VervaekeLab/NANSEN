function [ ] = stack2movie( filepath, imArray, framerate )
%stack2movie Saves a stack (array) as a movie on disk
%
%   stack2movie(filepath, imArray, framerate) saves an imageArray as a
%   video to the specified filepath. Framerate is optional (The default is 30)

if nargin < 3; framerate = 30; end

[filepath, filename, ~] = fileparts(filepath);

% Filepath to save the movie
if ismac
    filepath = fullfile(filepath, strcat(filename, '.mp4'));
    video = VideoWriter(filepath, 'MPEG-4');
    video.Quality = 100;
else
    filepath = fullfile(filepath, strcat(filename, '.avi'));
    video = VideoWriter(filepath);
end

video.FrameRate = framerate;
video.open();

nDim = numel(size(imArray));

% Write frames
if nDim == 3
    for i = 1:size(imArray, 3)
        frame = imArray(:, :, i);
        writeVideo(video, frame)
    end
elseif nDim == 4
    for i = 1:size(imArray, 4)
        frame = imArray(:, :, :, i);
        writeVideo(video, frame)
    end
end

video.close()

end
