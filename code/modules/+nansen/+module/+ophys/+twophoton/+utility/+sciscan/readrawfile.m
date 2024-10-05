function data=readrawfile(filename,skipframes,channel,frames)

%
%
%
% syntax:
% data=readrawfile(filename,skipframes,channel,frames);
%
% filename: a string containing the entire path and filename of the raw file
%               to read; leave empty to prompt file selection dialog
% skipframes: number of frames to skip at the beginning of the raw file
% channel: options are   'first' - loads only channel 1
%                        'second' - loads only channel 2
%                        'all' - loads all channels
% frames: number of frames to load; leave empty to load all frames
%
%
% usage examples:
%
% data=readrawfile;
%                   opens file selection dialog and loads all frames of
%                   selected raw file
%
% data=readrawfile('H:\test\(20131024_07_21_50)\(20131024_07_21_50)_test_XYT.raw');
%                   reads the specified file
%
% data=readrawfile([],10,'first');
%                   opens file selection dialog, skips the first ten frames, then loads all frames of
%                   channel 1 of the selected raw file
%
% data=readrawfile([],10,'second',100);
%                   opens file selection dialog, skips the first ten frames, then loads 100 frames of
%                   channel 2 of the selected raw file
%

prevstr=[];
if ~exist('filename') || ~ischar(filename)
    [FileName,PathName] = uigetfile('*.raw','Select raw data file');
    filename=fullfile(PathName,FileName);
end
if ~exist('channel') || ~ischar(channel)
    channel='all';
end

% obtain metadata from ini file
[pathstr, filenameWOext] = fileparts(filename);
inifilename=[filenameWOext '.ini'];
inistring=fileread(fullfile(pathstr,inifilename));
x=readinivar(inistring,'x.pixels');
y=readinivar(inistring,'y.pixels');
%framecount=readVarIni(inistring,'no..of.frames.to.acquire');
framecount=readinivar(inistring,'no.of.frames.acquired');
fileformat=readinivar(inistring,'file.format');

% count how many channels were recorded
recorded_ch=0;
for i=0:5;
    if strcmp(strtrim(char(readinivar(inistring,['save.ch.' num2str(i)]))),'TRUE') || strcmp(strtrim(char(readinivar(inistring,['ai.active' num2str(i)]))),'TRUE')
recorded_ch=recorded_ch+1;
    end
end

% determine bitdepth from file.format variable

if fileformat==1; % 32 bit raw file
  precparam1='*float32=>float32';
  precparam2=4;
  precparam3='single';
elseif fileformat==0; % 16 bit raw file
    precparam1='*uint16=>uint16';
    precparam2=2;
    precparam3='uint16';
else
    disp([filename ' is not a recognized file format.']);
return
end
    
if ~exist('frames') || isempty(frames)
    frames=framecount;
end

fid=fopen(filename,'r','b');

    if exist('skipframes') && ~isempty(skipframes)
        fseek(fid,skipframes.*recorded_ch.*precparam2.*prod([x y]),'bof');
    end
    
    switch channel
        
        case 'first'
            eval(['data=' precparam3 '(zeros(x*y,frames));']);
            for fr=1:frames;
                
% % %                 if ~rem(fr, 100) && frames > 1
% % %                     str=['loading frame ' num2str(fr) '/' num2str(frames)];
% % %
% % %                     refreshdisp(str,prevstr,fr);
% % %                     prevstr=str;
% % %                 end
                try
                data(:,fr)=fread(fid,prod([x y]),[num2str(prod([x y])) precparam1],(recorded_ch-1)*precparam2*prod([x y]));
                catch
                    fr=fr-1;
                    data=data(:,1:fr);
                    break
                end
            end
            data=reshape(data,[x y fr]);
            
        case 'second'
            eval(['data=' precparam3 '(zeros(x*y,frames));']);
            if recorded_ch > 1
                dump = fread(fid,prod([x y]),['1' precparam1]);
            end
            
            for fr=1:frames;
                
% % %                 if ~rem(fr,10) && frames > 1
% % %                     str=['loading frame ' num2str(fr) '/' num2str(frames)];
% % %
% % %                     refreshdisp(str,prevstr,fr);
% % %                     prevstr=str;
% % %                 end
                try
                data(:,fr)=fread(fid,prod([x y]),[num2str(prod([x y])) precparam1],(recorded_ch-1)*precparam2*prod([x y]));
                catch
                    fr=fr-1;
                    data=data(:,1:fr);
                    break
                end
            end
            data=reshape(data,[x y fr]);
            
        case 'all'
            y=y*recorded_ch;
            eval(['data=' precparam3 '(zeros(x*y,frames));']);
            
            for fr=1:frames;
% % %                 if ~rem(fr,10) && frames > 1
% % %                     str=['loading frame ' num2str(fr) '/' num2str(frames)];
% % %
% % %                     refreshdisp(str,prevstr,fr);
% % %                     prevstr=str;
% % %                 end
                try
                data(:,fr)=fread(fid,prod([x y]),[num2str(prod([x y])) precparam1]);
                catch
                    fr=fr-1;
                    data=data(:,1:fr);
                    break
                end
            end
            data=reshape(data,[x y/recorded_ch recorded_ch fr]);
            data=permute(data,[1 2 4 3]);
    end
    
% % % if frames > 1
% % %     fprintf(char(8*ones(1,length(prevstr))));
% % %     fprintf('Loaded all images.');
% % %     fprintf('\n');
% % % end

fclose(fid);
