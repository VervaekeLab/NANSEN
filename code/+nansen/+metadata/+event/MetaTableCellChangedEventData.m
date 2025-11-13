classdef MetaTableCellChangedEventData < event.EventData & matlab.mixin.SetGet
    properties
        RowIndex (1,1) {mustBeInteger, mustBePositive} = 1
        ColumnIndex (1,1) {mustBeInteger, mustBePositive} = 1
        NewValue
    end

    methods
        function obj = MetaTableCellChangedEventData(propertyArgs)
            arguments
                propertyArgs.RowIndex (1,1) {mustBeInteger, mustBePositive}
                propertyArgs.ColumnIndex (1,1) {mustBeInteger, mustBePositive}
                propertyArgs.NewValue
            end

            obj.set(propertyArgs)
        end
    end
end
