classdef DateRangeSelector < handle & uiw.mixin.AssignPVPairs
%DateRangeSelector Simple wrapper for a DateChooserPanel widget

    properties
        Callback
        Parent
        Position = [1,1,230,230];
        BorderColor = [0.5, 0.5, 0.5]
    end

    properties (Dependent)
        SelectedDateInterval
        Visible
    end

    properties (Access = private)
        hDatePanel
        hContainer
    end

    methods

        function obj = DateRangeSelector(varargin)

            if nansen.util.useModernUiComponents()
                % MATLAB R2025a removed JAVA support, abort.
                error("NANSEN:DateRangeSelector:NotSupported", ...
                    "This component is not supported on MATLAB R2025 or newer.")
            end

            obj.assignPVPairs(varargin{:})

            warnCleanup = nansen.ui.legacy.tempDisableJavaFrameWarnings();
            warnCleanup(end+1) = nansen.ui.legacy.tempDisableJavaComponentWarning(); %#ok<NASGU>

            com.mathworks.mwswing.MJUtilities.initJIDE; %#ok<JAPIMATHWORKS>

            % Display a DateChooserPanel
            jDatePanel = com.jidesoft.combobox.DateChooserPanel;
            [obj.hDatePanel, obj.hContainer] = javacomponent(jDatePanel, ...
                obj.Position, obj.Parent); %#ok<JAVCM>

            jModel = obj.hDatePanel.getSelectionModel;  % a com.jidesoft.combobox.DefaultDateSelectionModel object
            jModel.setSelectionMode(jModel.SINGLE_INTERVAL_SELECTION);

            % Make custom border;
            mRgb = obj.BorderColor;
            borderColor = java.awt.Color(mRgb(1), mRgb(2), mRgb(3));
            tableBorder = javax.swing.border.LineBorder(borderColor, 1, 0); % color, thickness, rounded corners (tf)
            obj.hDatePanel.setBorder(tableBorder)

            f = java.awt.Font("avenir next", java.awt.Font.PLAIN, 12);
            set(obj.hDatePanel, 'Font', f);

            hModel = handle(obj.hDatePanel.getSelectionModel, 'CallbackProperties');
            set(hModel, 'ValueChangedCallback', obj.Callback);
        end
    end

    methods
        function reset(obj)
        %reset Clear the selected date interval.
        %
        %   Clear the selection model so the filter reads no interval, and
        %   call setSelectedDate(null) so the calendar view stops showing the
        %   previous selection. Clearing the model alone does not refresh the
        %   panel display. Passing [] sends a Java null.
            obj.hDatePanel.getSelectionModel.clearSelection()
            obj.hDatePanel.setSelectedDate([])
        end

        function dateInterval = get.SelectedDateInterval(obj)
            selectedDates = obj.hDatePanel.getSelectionModel.getSelectedDates();

            if isempty(selectedDates), dateInterval = []; return; end

            initialDate = selectedDates(1);
            finalDate = selectedDates(end);

            pivotYear = 1900;

            initialDate = datetime(initialDate.getYear + pivotYear, initialDate.getMonth+1, initialDate.getDate);
            finalDate = datetime(finalDate.getYear + pivotYear, finalDate.getMonth+1, finalDate.getDate);

            dateInterval = [initialDate, finalDate];
        end

        function set.Position(obj, newValue)
            obj.Position = newValue;
            obj.onPositionChanged()
        end

        function set.Visible(obj, newValue)
            if ~isempty(obj.hContainer)
                obj.hContainer.Visible = newValue;
            end
        end

        function visible = get.Visible(obj)
            if ~isempty(obj.hContainer)
                visible = obj.hContainer.Visible;
            else
                visible = 'off';
            end
        end

        function set.Callback(obj, newValue)
            obj.Callback = newValue;
            obj.onCallbackPropertySet()
        end
    end

    methods (Access = private)

        function onCallbackPropertySet(obj)
            % The Callback property may be set via assignPVPairs before the
            % date panel exists. Skip here in that case; the constructor wires
            % the callback once the panel has been created.
            if isempty(obj.hDatePanel)
                return
            end
            hModel = handle(obj.hDatePanel.getSelectionModel, 'CallbackProperties');
            set(hModel, 'ValueChangedCallback', obj.Callback);
        end

        function onPositionChanged(obj)
            if ~isempty(obj.hContainer)
                obj.hContainer.Position = obj.Position;
            end
        end

        function onVisibleChanged(obj)
            if ~isempty(obj.hContainer)
                obj.hContainer.Visible = obj.Visible;
            end
        end
    end
end
