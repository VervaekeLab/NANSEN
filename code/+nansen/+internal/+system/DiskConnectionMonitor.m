classdef DiskConnectionMonitor < handle
    
    % Todo
    %   - Streamline getting drive info from nansen.external.fex.sysutil.listMountedDrives
    %   - Create event data?
    %   - Use drive instead of disk in class/method/event names

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

            if ispc || (isunix && ~ismac)
                if ~obj.checkListDrivesWorks()
                    obj.displayListDrivesNotWorkingWarning()
                    return
                end
            end

            obj.initializeTimer()
        end

        function delete(obj)
            if ~isempty(obj.Timer) && isvalid(obj.Timer)
                obj.Timer.stop()
                delete(obj.Timer)
            end
        end
    end

    methods
        function pause(obj)
            obj.Timer.stop()
        end

        function resume(obj)
            obj.Timer.start()
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
            obj.Timer.start()
        end
        
        function updateDiskList(obj, updatedVolumeList)
            
            if isempty(obj.VolumeList)
                obj.VolumeList = updatedVolumeList; return
            end
            
            % Check if any names were added
            oldNames = {obj.VolumeList.Name};
            newNames = {updatedVolumeList.Name};

            % Update volumelist
            obj.VolumeList = updatedVolumeList;
            
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
        end

        function checkDiskPc(obj)
            %volumeList = system.
            volumeInfoTable = nansen.external.fex.sysutil.listMountedDrives();
            
            % Convert string array to cell array of character vectors in
            % order to create struct array below
            string2cellchar = @(strArray) arrayfun(@char, strArray, 'uni', false); %convertStringsToChars, cellstr
            volumeList = struct('Name', string2cellchar(volumeInfoTable.VolumeName), ...
                                'MountLetter', string2cellchar(volumeInfoTable.DeviceID) );
            
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
            volumeInfoTable = nansen.external.fex.sysutil.listMountedDrives();
            
            % Convert string array to cell array of character vectors in
            % order to create struct array below
            string2cellchar = @(strArray) arrayfun(@char, strArray, 'uni', false); %convertStringsToChars, cellstr
            volumeList = struct('Name', string2cellchar(volumeInfoTable.VolumeName) );
            
            obj.updateDiskList(volumeList)
        end
    
        function tf = checkListDrivesWorks(~)
            persistent listDrivesWorks
            if isempty(listDrivesWorks)
                try
                    nansen.external.fex.sysutil.listMountedDrives()
                    listDrivesWorks = true;
                catch
                    listDrivesWorks = false;
                end
            end
            tf = listDrivesWorks;
        end

        function displayListDrivesNotWorkingWarning(~)
            nansen.common.tracelesswarning(sprintf([...
                'Failed to list mounted drives using system command.\nIf you ', ...
                'want NANSEN to dynamically update when drives are ', ...
                'connected/disconnected, please run ', ...
                '`nansen.external.fex.sysutil.listMountedDrives` and ', ...
                'report the error you are seeing.']))
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
