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
%
% See also: DECIMATE


newR = ceil(size(t_in,1)/R);

TDn = zeros(newR,size(t_in,2));

for i=1:size(t_in,2),
    TDn(:,i) = decimate(t_in{:,i},R);
end;

t_out = array2timetable(TDn,"RowTimes",t_in.Time(1:R:end),"VariableNames", t_in.Properties.VariableNames);
