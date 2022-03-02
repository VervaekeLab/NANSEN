function [IM, batchSize, lineShifts] = correctLineOffsets(IM, batchSize)
%correctLineOffsets Correct line offsets in 2p recording due to bidir scan
%   [IM, batchSize, lineShifts] = correctLineOffsets(IM, batchSize)
%   corrects line by line shifts due to bidirectional offsets in the
%   resonance line by line scanning. batchSize is number of frames to
%   process together. 
%
%   This function increases the batchSize automatically if the shifts does 
%   not change between two batches. This is done because the line offsets 
%   are typically changing more in the beginning of the recording before 
%   becoming more or less stable for the rest of the recording.
%   
%   The function also return the lineShifts that are detected. lineShifts
%   is a vector of (nFrames x 1)
%
%   NB: This function requires NoRMCorre
%       (https://github.com/flatironinstitute/NoRMCorre)
%
%   Written by Eivind Hennestad | Vervaeke Lab
    
% Do the bidirectional offset correction.
nFrames = size(IM, 3);
colShiftPrev = [];
finished = false; 
    
lineShifts = zeros(nFrames, 1);

% Do it in smaller batches. Mostly relevant in the beginning of a scan
first = 1;
while ~finished
        
    if first + batchSize >= nFrames
        last = nFrames;
        finished = true;
    else
        last = first + batchSize - 1;
    end
    
    ind = first:last;
    
    [colShift, IM(:,:,ind)] = correct_bidirectional_offset(IM(:,:,ind), numel(ind), 10);
    lineShifts(first:last) = colShift;
        
    if ~isempty(colShiftPrev)
        if colShiftPrev == colShift
            batchSize = batchSize * 2;
        end
    end
        
    colShiftPrev = colShift;
    first = last+1;
    
end

end