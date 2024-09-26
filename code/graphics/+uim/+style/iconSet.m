classdef iconSet < uim.handle
%iconSet Class for interfacing an icon library.
%
% How to use: Create a folder and add pngs with icons. Preferably high
% resolution (Also, currently, only monocolor icons are supported).
% Initialize the iconSet with a reference (path string) to the folder and
% use the addIcon method to add icons to the library. New icons are
% automatically saved in the library file.
%
% IconData for an icon is received by calling iconSet.iconName where
% iconName is the name of the icon.

% Todo:
%   Implement remove icons
%   Add multiple icons in one go
%   Create colorful icons

    properties
        iconDir                 % Path to folder where icons are saved
        filePath                % File path to the icon library file
        iconNames               % Name of icons in set
        iconData = struct       % Data of icons in set
    end
    
    methods %Structors
        function obj = iconSet(pathStr)
        %iconSet Initialize an iconSet for an icon library
        %
        %   obj = iconSet(pathStr)
        
            obj.iconDir = pathStr;
            obj.filePath = fullfile(obj.iconDir, 'icon_library.mat');
            
            obj.loadIcons();
        end
    end
    
    methods
        
        function varargout = subsref(obj, s)
            varargout = cell(1, nargout);

            switch s(1).type

                % Use builtin if a property is requested.
                case '.'
                    if ~isempty(obj.iconNames) && numel(s)==1 && contains(s.subs, obj.iconNames)
                        if ~nargout
                            varargout = {obj.iconData.(s.subs)};
                        else
                            [varargout{:}] = obj.iconData.(s.subs);
                        end
                    else
                        if ~nargout
                            builtin('subsref', obj, s)
                        else
                            [varargout{:}] = builtin('subsref', obj, s);
                        end
                    end
                % Use builtin if a parenthesis are used.
                case '()'
                    if ~nargout
                        builtin('subsref', obj, s)
                    else
                        [varargout{:}] = builtin('subsref', obj, s);
                    end
            end
        end
        
        function loadIcons(obj)
        %LOADICONS Load icons from matfile
        
            if exist(obj.filePath, 'file')
                obj.iconData = load(obj.filePath);
            end
            
            obj.iconNames = fieldnames(obj.iconData);
        end
        
        function saveIcons(obj, S)
        %SAVEICONS Save icons to matfile
        
            if nargin < 2
                S = obj.iconData;
            end
            
            if ~exist(obj.filePath, 'file')
                save(obj.filePath, '-struct', 'S');
            else
                save(obj.filePath, '-struct', 'S', '-append');
            end
        end
        
        function listIcons(obj)
            fprintf([strjoin(obj.iconNames, '\n'), '\n'])
        end
        
        function addIcon(obj, iconName, S)
        %addIcon Add icon to the library
        %
        %   addIcon(obj, iconName) converts a png to matlab patch data and
        %   saves it to the icon library. iconName must be the name of a
        %   png-file in the iconSet's root directory.
        
            if nargin < 2
                S = obj.createIcon(obj.iconDir);
            elseif nargin < 3
                S = obj.createIcon(obj.iconDir, iconName);
            end
            
            if ~isempty(S)
                obj.saveIcons(S)
            end
            
            iconNames = fieldnames(S);

            for i = 1:numel(iconNames)
                obj.iconData.(iconNames{i}) = S.(iconNames{i});
            end
            
            obj.iconNames = fieldnames(obj.iconData);
            
        end
        
        function addIconFromFile(obj, iconName, filePath)
            
            if nargin < 3
                [fileName, folder] = uigetfile();
                if fileName == 0; return; end
                filePath = fullfile(folder, fileName);
            end
            
            S = load(filePath);
            
            if nargin < 2
                iconName = inputdlg();
                if isempty(iconName); return; end
                iconName = iconName{1};
            end
            
            newS = struct();
            newS.(iconName) = S.imageVector;
            obj.addIcon(iconName, newS)
            
        end
        
        function removeIcon(obj, iconName)
            
            isMatch = contains(obj.iconNames, iconName);
            
            if any(isMatch)
                obj.iconData = rmfield(obj.iconData, iconName);
            end
            
            obj.iconNames = fieldnames(obj.iconData);
            
        end
        
        function setSimplifyFalse(obj)
            
            names = obj.iconNames;
            
            for i = 1:numel(names)
                for j = 1:numel(obj.iconData.(names{i}))
                    p1 = obj.iconData.(names{i})(j).Shape;
                    p2 = polyshape(p1.Vertices, 'Simplify', false);
                    obj.iconData.(names{i})(j).Shape = p2;
                end
            end
        end
    end
    
    methods (Access = private)
% %         function filePath = getIconPackagePath(obj)
% %
% %         end
    end
    
    methods (Static)
        
        function S = createIcon(rootDir, iconName, plotType)
        %createIcon Create icondata from a png file
        %
        %   Loads the pngs, converts the shapes in the png to boundary
        %   coordinates and creates a set of patch properties that can
        %   later be plotted using the patch function.
        %
        %   S = createIcon(rootDir, iconName, plotType) returns a struct of
        %   patch properties (S) given rootDir (directory with png files) and
        %   iconName (name of icon png file). plotType can be 'patch'
        %   (default) or 'polygon'. Not sure why I would ever want to use
        %   polygon...
            
            % Preallocate output
            S = struct.empty();
            
            if nargin < 3; plotType = 'polygon'; end
            
            L = dir(fullfile(rootDir, '*.png'));
    
            [~, iconName] = fileparts(iconName);
            
            if nargin >= 2 || exist('iconName', 'var')
                IND = find(strcmp({L.name}, [iconName, '.png'] ));
            else
                IND = 1:numel(L);
            end

            fig = figure('Visible', 'off');
            ax = axes(fig);
            axis equal
            
            for i = IND
                imageName = L(i).name;

                loadPath = fullfile(rootDir, imageName);

                im = imread(loadPath);
                hP = uim.graphics.patchLineDrawing(ax, im, 'cropImage', true, ...
                    'SmoothWindow', 5, 'plotType', plotType);

                switch plotType
                    case 'polygon'
                        % Get the shape and the colors and save to a mat-file
                        polyShape = arrayfun(@(h) h.Shape, hP, 'uni', 0);
                        colors = arrayfun(@(h) h.FaceColor, hP, 'uni', 0);

                        V = struct('Shape', polyShape, 'Color', colors); %#ok<NASGU>
                        delete(hP)

                        hV = uim.graphics.imageVector(ax, V);
                        
                    case 'patch'
                        V = struct('Faces', {hP.Faces}, 'Vertices', {hP.Vertices}, ...
                            'FaceColor', {hP.FaceColor}, 'EdgeColor', {'none'});
                        delete(hP)
                        
                        hV = imageVector(ax, V);
                        hV.center()
                end

                % normalize vector image to have height 1.
                hV.Height = hV.Height/hV.Height;

                if isempty(S)
                    S = struct(iconName, hV.getVectorStruct);
                else
                    S.(iconName) = hV.getVectorStruct;
                end
                
                delete(hV)

            end
            
            close(fig)

        end
    end
end
