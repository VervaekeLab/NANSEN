function BW = binarizeStack(imArray, obj, datatype)
%autosegment.binarizeStack Binarize imageStack for autosegmentation
if nargin < 2
    obj = [];
end

if nargin < 3
    datatype = 'soma';
end


%% Preprocess (subtract background)
tmpStack = single(imArray);
            

% Create a temporally downsampled stack (binned by maximum) 
tmpStack2 = stack.process.framebin.max(tmpStack, 5);

% Smooth using a big gaussian kernel, to wash out cell-sized objects
bgStack = stack.process.filter2.gauss2d(tmpStack2, 20);

% Subtract background (smoothed version) 
tmpStack2 = tmpStack2 - bgStack;


%% Calculate a dff stack. Should create separate function.
sorted = sort(tmpStack2, 3);
baseline = mean(sorted(:, :, 1:round(size(sorted,3)*0.25)), 3);
dffStack = tmpStack2-baseline;

% Normalize dffStack
dffStack = dffStack-min(dffStack(:));
dffStack = dffStack./max(dffStack(:));


%% Binarize images
if ~isempty(obj)
    obj.waitbar(0, 'Please wait while binarizing images');
end

switch datatype
    case 'soma'
        BW = binarizeSomaData(dffStack, obj);
    case 'axon'
        BW = binarizeAxonData(dffStack, obj);
end
       
 
if ~isempty(obj)
    obj.waitbar([], [], 'close')
end

end





function BW = binarizeSomaData(dffStack, obj)

    BW = false(size(dffStack));

    % Todo: Should these depend on roi size??
    nhood1 = strel('disk', 1);
    nhood2 = strel('disk', 2);
    nhood3 = strel('disk', 3);
    nhood4 = strel('disk', 4);


    T = prctile(dffStack(:), 92);

    for i = 1:size(dffStack, 3)
    %                 T = adaptthresh(dffStack(:,:,i), 0.5); %'ForegroundPolarity', 'bright'
    %                 BW(:,:,i) = imbinarize(dffStack(:,:,i), T);

    %     pixelData = dffStack(:,:,i);
    %     T = prctile(pixelData(:), 92);

        BW(:,:,i) = imbinarize(dffStack(:,:,i), T);
        BW(:,:,i) = imfill(BW(:,:,i),'holes');

    %                 BW(:,:,i) = bwareaopen(BW(:,:,i), 20);
    %                 BW(:,:,i) = imclose(BW(:,:,i), nhood2);
        BW(:,:,i) = imopen(BW(:,:,i), nhood2);

        BW(:,:,i) = imdilate(BW(:,:,i), nhood4);
        BW(:,:,i) = imclearborder(BW(:,:,i));
        BW(:,:,i) = imerode(BW(:,:,i), nhood4);
        BW(:,:,i) = imopen(BW(:,:,i), nhood4);
    
        if ~isempty(obj) && mod(i,50)==0
            obj.waitbar(i/size(dffStack, 3))
        end
        
    end
    

end




function BW = binarizeAxonData(dffStack, obj)

    T = prctile(dffStack(:), 95);
    BW = false(size(dffStack));
    
    for i = 1:size(dffStack, 3)

        BW(:,:,i) = imbinarize(dffStack(:,:,i), T);

        BW(:,:,i) = imclearborder(BW(:,:,i));
        BW(:,:,i) = bwareaopen(BW(:,:,i), 5);
        
        if ~isempty(obj) && mod(i,50)==0
            obj.waitbar(i/size(dffStack, 3))
        end
    end

end


% % % % Old test code
% % % 
% % %     BW = false(size(dffStack));
% % % 
% % %     nhood1 = strel('disk', 1);
% % %     nhood2 = strel('disk', 2);
% % %     nhood3 = strel('disk', 3);
% % %     nhood4 = strel('disk', 4);
% % % 
% % % 
% % %     T = prctile(dffStack(:), 92);
% % % 
% % %     for i = 1:size(dffStack, 3)
% % %    
% % %         dbIm = imbinarize(dffStack(:,:,i), T);
% % % 
% % %         % Fill holes. Some rois with donut shapes can be so dark
% % %         % within that the inside pixels are below the threshold.
% % %         % When opening the image they disappear, so first step is
% % %         % to use the fill holes.
% % %         dbIm(:, :, end+1) = imfill(dbIm(:, :, end) ,'holes');
% % % 
% % %         % Remove small objects. Can use either bwareaopen or
% % %         % imopen.
% % % 
% % %         dbIm(:, :, end+1) = bwareaopen(dbIm(:, :, end), 20);
% % %         dbIm(:, :, end+1) = imclose(dbIm(:, :, end), nhood2);
% % %         dbIm(:, :, end+1) = imopen(dbIm(:, :, end), nhood2);
% % % 
% % % %                 % Is this needed:
% % % %                     e = imclose(d, nhood2);
% % % 
% % %         % Remove objects withing 4 pixels of border
% % %         dbIm(:, :, end+1) = imdilate(dbIm(:, :, end), nhood4);
% % %         dbIm(:, :, end+1) = imclearborder(dbIm(:, :, end));
% % %         dbIm(:, :, end+1) = imerode(dbIm(:, :, end), nhood4);
% % % 
% % %         % Remove small objects again.
% % %         dbIm(:, :, end+1) = imopen(dbIm(:, :, end), nhood4);
% % % 
% % %         imviewer(dbIm)
% % %         
% % %     end
    
