function t_out = range(t_in,R)
% RANGE - downsample a timetable and let the Y values reflect the range
%
% T_OUT = RANGE(T_IN, R)
%
% Downsample a timetable object by creating a table that is subsampled and
% reflects the range of the points that are aggregated. The new vector
% alternates between the min and the max of the data in each bin. That is,
% Y values in each column are concatenated as:
%   [Y_new_bin_x Y_new_bin_x+1] = [ Y_bin_x_min Y_bin_x_max Y_bin_x+1_max Y_bin_x+1_min ] 
% and so on. 
% 
% The number of timestamps of the returned table is 2*ceil(size(t_in,1)/R);
% 
% See also: TIMETABLE

sampleRateEpsilon = 0.01;

sampleRate = t_in.Properties.SampleRate;
if isnan(sampleRate)
    tDiff = diff(t_in.Time);
    tDiffMean = mean(tDiff);
    
    tDiffMax = max(tDiff);
    tDiffMin = min(tDiff);

    if abs(tDiffMean-tDiffMax) > tDiffMean*sampleRateEpsilon || ...
        abs(tDiffMean-tDiffMin) > tDiffMean*sampleRateEpsilon
        warning('Constant sampling rate assumption might be wrong.')
    end
    sampleRate = 1/seconds(tDiffMean);
end

newR = ceil(size(t_in,1)/R);

t_max = retime(t_in,'regular','max','SampleRate',sampleRate/R);
t_min = retime(t_in,'regular','min','SampleRate',sampleRate/R);

sample = reshape(repmat(1:newR,2,1),2*newR,1);
dataset_max = find(mod(1:2*newR,4)>1);
sample(dataset_max) = sample(dataset_max)+newR;

total_set = cat(1,t_min{:,:},t_max{:,:});

t_out = array2timetable(total_set(sample,:),"VariableNames",t_in.Properties.VariableNames,"StartTime",t_min.Time(1),"SampleRate",2*t_min.Properties.SampleRate);
