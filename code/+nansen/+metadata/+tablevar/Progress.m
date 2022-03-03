classdef Progress < nansen.metadata.abstract.TableVariable
%nansen.metadata.tablevar.Progress is a table variable for showing progress
%
%   Display the progress of a pipeline as a progressbar or list of steps
%   indicating if they are finished or not.
%
%   See also nansen.metadata.abstract.TableVariable
    
    properties (Constant)
        IS_EDITABLE = false
        DEFAULT_VALUE = struct.empty
    end
    
    methods
        
        function obj = Progress(S)
            if nargin < 1; S = struct.empty; end
            obj@nansen.metadata.abstract.TableVariable(S);
            assert( all( arrayfun(@isstruct, [obj.Value])), 'Value must be a struct')
        end
        
        function progressBarString = getCellDisplayString(obj)
        %getCellDisplayString Format the progress struct into a progressbar
        
            % Todo:
            %   [ ] Colors do not always look very good
            %   [ ] Colors and fontsize should be adjustable.
            
            % Only assign the colors for the colorbar once
            persistent hexColorDark hexColorLight
            
            if isempty(hexColorDark) || isempty(hexColorLight)
                [hexColorLight, hexColorDark] = obj.getProgressBarColors();
            end
                        
            % obj.Value is a struct of logicals. Convert to array and 
            % calculate mean to get the percentwise progress.
            
            progressBarString = cell(1, numel(obj));
            
            for i = 1:numel(obj)
            
                % Convert structure to cell and then to an array.
                if isstruct(obj(i).Value) && isfield(obj(i).Value, 'IsFinished')
                    isDone = [ obj(i).Value.IsFinished ] ;
                    mode = 'Standard';
                else
                    isDone = cell2mat( struct2cell(obj(i).Value) );
                    mode = 'Unassigned';
                    progressBarString{i} = 'N/A'; continue
                end
                pctProgress = mean(isDone);
            
                % TODO: Should be variable based on available space...
                nLines = 48;

                if isnan(pctProgress)
                    pctProgress = 0;
                end
            
                % Create vertical bars for pctProgress and pctRemaining
                n1 = ceil(nLines * pctProgress);
                n2 = nLines - n1;

                str1 = repmat('|', 1, n1);
                str2 = repmat('|', 1, n2);

                % Use HTML to format string of vertical bars in different colors.
                progressBarString{i} = sprintf(['<HTML>', ...
                    '<FONT color="%s" size="-2"><b>%s</Font>', ...
                    '<FONT color="%s" size="-2"><b>%s</Font>', ...
                    '</HTML>'], hexColorDark.(mode), str1, hexColorLight.(mode), str2);
            end
            
        end
        
        function progressTooltipString = getCellTooltipString(obj)
            
            % Todo: Should sessionID be injected here?
            
% %             if isa(metaVar, 'struct')
% %                 progressStruct = metaVar.Progress;
% %             elseif isa(metaVar, 'table') %TODO: Test
% %                 progressStruct = metaVar.Progress;
% %             else
% %                 
% %             end

            progressStruct = obj.Value;
            
            if isa(progressStruct, 'cell')
                progressStruct = progressStruct{1};
            end
            
            if isempty(progressStruct)
                progressTooltipString = '';
            else
                
                % Create a struct for the struct array...
                progressStruct = obj.taskList2TaskStatus(obj.Value);
                
                % Format struct into a multiline string:
                structStr = evalc('disp(progressStruct)');
                
                while true % Remove trailing newlines...
                    if strcmp(structStr(end),  sprintf('\n'))                   %#ok<SPRINTFN>
                        structStr(end)='';
                    else
                        break
                    end
                end
                structStr = strrep(structStr, sprintf('\n'), '<br />');         %#ok<SPRINTFN>
                
                % This is hanging around from previous implementation.
                % structStr = [sprintf('<b>%s:</b> <br />', metaVar.sessionID{1}), structStr];
                
                % Align all lines to the right, i.e justify at the : sign 
                % since all struct values are same length (0 or 1).
                str = sprintf('<html><div align="right"> %s </div>', structStr);
                
                progressTooltipString = str;
                
            end
            
        end
             
        function onCellDoubleClick(obj, metaObj, varargin)
            
            if ~isempty(obj.Value)
                obj.openPipelineViewerUI(metaObj, varargin{:});
            end
            
        end
    end
    
    methods (Access = private)
       
        function hApp = openPipelineViewerUI(obj, metaObj, varargin)
              
            hApp = obj.getPipelineViewerApp();
            hApp.Visible = 'on';
            
            hApp.openPipeline(obj.Value, metaObj);
            
        end
        
    end
    
    methods (Static)
        
        function hApp = getPipelineViewerApp()
            
            global PipelineViewer
            
            if isempty(PipelineViewer) || ~isvalid(PipelineViewer)
                PipelineViewer = nansen.pipeline.PipelineViewerApp();
                PipelineViewer.setClosePolicy('hide')
            end
            
            hApp = PipelineViewer;
            
        end
        
        function taskStatus = taskList2TaskStatus(taskList)
            
            taskStatus = struct;
            
            for i = 1:numel(taskList)
               
                fcnName = taskList(i).TaskName;
                if taskList(i).IsFinished
                    status = 'finished';
                else
                    status = 'unfinished';
                end
                
                taskStatus.(fcnName) = status;
                
            end
            
            
        end
        
        function [colorLight, colorDark] = getProgressBarColors()
        %getProgressBarColors Get colors for colorbar        
            
        
            % Try to get colors from to UIManager, otherwise use hardcoded.
            % Todo: Should not be hardcoded...
            
            try
                color = javax.swing.UIManager.get('Focus.color');
                rgb = cellfun(@(name) get(color, name), {'Red', 'Green', 'Blue'});
            catch
                rgb = [47, 118, 181];
            end
            
            % Special case...
% %             if isequal(rgb, [7, 76, 241])
% %                 colorDark = '2F76B5'; % 'FFC000'; %(yellow) - '70AD47' %(green);
% %                 colorLight = 'DFEBF7'; % 'FFF3CC'; %(yellow) - 'C5E0B3' %(green);
% % 
% %             else % Hardocde all of them??? Details matter ffs!

                hsv = rgb2hsv(rgb./255);

                % Use hsv to change brightness, guarantees getting a
                % valid color...
                hsvA = hsv;% .* [1, 1, min([1.1, 1/hsv(3)]) ];
                hsvB = hsv .* [1, 0.5, min([1.4, 1/hsv(3)]) ];

                
                % Some alternatives. Keep for posterity...
%                     hsvA = hsv .* [1, 0.9, 0.9];% .* [1, 1, min([1.1, 1/hsv(3)]) ];
%                     hsvB = hsv .* [1, 0.5, min([1.4, 1/hsv(3)]) ];
% 
%                 hsv(2) = hsv(2)/2;
%                 hsv(3) = min([hsv(3)*1.4, 1]);
                
                rgbC = ones(1,3) .* 0.75;
                rgbD = ones(1,3) .* 0.75;


                [colorDark, colorLight] = deal(struct);
            
    
                colorDark.Standard = uim.utility.rgb2hex( hsv2rgb(hsvA) );
                colorLight.Standard = uim.utility.rgb2hex( hsv2rgb(hsvB) );
                
                colorDark.Unassigned = uim.utility.rgb2hex( rgbC );
                colorLight.Unassigned = uim.utility.rgb2hex( rgbD );
                
% %             end
            
        end
        
    end
    
end