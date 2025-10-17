function saveIcon(iconName)

    rootDir = fileparts(mfilename('fullpath'));
    L = dir(fullfile(rootDir, '*.png'));
    
    if nargin >= 1
        IND = find(contains({L.name}, iconName ));
    else
        IND = 1:numel(L);
    end
    
    for i = IND
        imageName = L(i).name;
    
        loadPath = fullfile(rootDir, imageName);

        im = imread(loadPath);

        fig = figure('Visible', 'off');
        ax = axes;
        axis equal

        hP = utilities.patchLineDrawing(ax, im, 'cropImage', true);
        % Get the shape and the colors and save to a mat-file
        polyShape = arrayfun(@(h) h.Shape, hP, 'uni', 0);
        colors = arrayfun(@(h) h.FaceColor, hP, 'uni', 0);

        V = struct('Shape', polyShape, 'Color', colors); %#ok<NASGU>
        delete(hP)

        hV = uim.graphics.imageVector(ax, V);

        hV.Height = hV.Height/hV.Height;

        S.imageVector = hV.getVectorStruct;
        savePath = strrep(loadPath, '.png', '.mat');

        save(savePath, '-struct', 'S')
    end
end
