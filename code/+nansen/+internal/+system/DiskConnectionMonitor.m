classdef DiskConnectionMonitor < handle
    
    properties (Dependent)
        TimerUpdateInterval
    end

    properties (SetAccess = private)
        VolumeList (1,:) struct
    end

    properties (Access = private)
        Timer (1,1) timer
        TimerUpdateInterval_ = 5
    end

    events
        DiskAdded
        DiskRemoved
    end

    % Structors
    methods
        
        function obj = DiskConnectionMonitor
            obj.initializeTimer()
        end

        function delete(obj)
            if ~isempty(obj.Timer)
                stop(obj.Timer)
                delete(obj.Timer)
            end
        end

    end

    methods % Set/get
        
        function set.TimerUpdateInterval(obj, newValue)
            if isnumeric(newValue)
                newValue = seconds(newValue);
            end

            if ~isempty(obj.Timer)
                obj.Timer.Period = newValue;
            end
            obj.TimerUpdateInterval_ = newValue;
        end

        function period = get.TimerUpdateInterval(obj)
            period = obj.TimerUpdateInterval_;
        end

    end

    methods (Access = private)
       
        function initializeTimer(obj)
            updateFcn = obj.getUpdateFunction();
            
            obj.Timer = timer('Name', 'DiskConnectionMonitorTimer');
            obj.Timer.ExecutionMode = 'fixedRate';
            obj.Timer.Period = obj.TimerUpdateInterval_;
            obj.Timer.TimerFcn = updateFcn;
            start(obj.Timer)
        end
        
        function updateDiskList(obj, updatedVolumeList)
            
            if isempty(obj.VolumeList)
                obj.VolumeList = updatedVolumeList; return
            end
            
            % Check if any names were added
            oldNames = {obj.VolumeList.Name};
            newNames = {updatedVolumeList.Name};
            
            [addedNames, idx] = setdiff(newNames, oldNames);
            if ~isempty(addedNames)
                fprintf('Added drives %s\n', addedNames{1});
                obj.notify('DiskAdded', event.EventData)
            end

            % Check if any names were removed
            [removedNames, idx] = setdiff(oldNames, newNames);
            if ~isempty(removedNames)
                fprintf('Removed drives %s\n', removedNames{1});
                obj.notify('DiskRemoved', event.EventData)
            end

            obj.VolumeList = updatedVolumeList;
        end


        function checkDiskPc(obj)
            %volumeList = system.
            volumeInfoTable = nansen.external.fex.sysutil.listPhysicalDrives();

            volumeList = struct('Name', {volumeInfoTable.VolumeName}, ...
                                'MountLetter', {volumeInfoTable.DeviceID} );

            obj.updateDiskList(volumeList)
        end

        function checkDiskMac(obj)
            volumeListDir = dir('/Volumes');
            keep = not( strncmp({volumeListDir.name}, '.', 1) ); 
            volumeListDir = volumeListDir(keep);
            
            %fprintf('%s\n', strjoin( {volumeListDir.name}, ', '))

            volumeList = struct('Name', {volumeListDir.name});
            
            obj.updateDiskList(volumeList)
        end

        function checkDiskUnix(obj)
            error('Not implemented yet')
        end
    end

    methods (Access = private)

        function updateFcn = getUpdateFunction(obj)
            
            if ispc
                updateFcn = @(timer, event) obj.checkDiskPc;
            elseif ismac
                updateFcn = @(timer, event) obj.checkDiskMac;
            elseif isunix
                updateFcn = @(timer, event) obj.checkDiskUnix;
            else
                error('Unknown platform')
            end
        end

    end

end