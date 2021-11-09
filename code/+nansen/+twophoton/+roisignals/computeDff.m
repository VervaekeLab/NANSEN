function dff = computeDff(signalArray, varargin)

    P = struct;
    P.baseline = 20;
    P.dffFcn = 'dffClassic';
    P.dffFcn_ = getDffMethodChoices();
    
    P.correctBaseline = false;
    P.correctionWindowSize = 500;
    P.correctionPrctile = 25;
    P.correctionPrctile_ = struct('type', 'slider', 'args', {{'Min', 0, 'Max', 100, 'nTicks', 101, 'TooltipPrecision', 0}});

    if ~nargin 
        dff = P; return
    end
    
    params = utility.parsenvpairs(P, [], varargin{:});
    
    dffPackage = 'nansen.twophoton.roisignals.process.dff';
    dffFunction = str2func( strjoin({dffPackage, params.dffFcn}, '.') );
    
    dff = dffFunction(signalArray, params);
    
% %     %sz1 = size(signalArray);
% %     %sz2 = size(dff);
% %     %fprintf('Size before: %d, %d, Size after: %d, %d\n', sz1(1), sz1(2), sz2(1), sz2(2))
        
    if params.correctBaseline
        
        p = params.correctionPrctile;
        window = params.correctionWindowSize;
        shift =round(window/5);
        
        dff = prctfilt(dff', p, window, shift);
        dff = dff';
        
        %dff = dff - movmedian(dff, window);
        
    end
    
end


function choices = getDffMethodChoices()
    
    persistent fileNames
    
    if isempty(fileNames)

        S = matlab.internal.language.introspective.resolveName('nansen.twophoton.roisignals.process.dff');
        dirPath = S.nameLocation;

        L = dir(fullfile(dirPath, '*.m'));
        fileNames = {L.name};
        fileNames = strrep(fileNames, '.m', '');

    end
    
    choices = fileNames; 
end