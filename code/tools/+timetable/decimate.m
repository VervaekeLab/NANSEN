function t_out = decimate(t_in,R)
% DECIMATE - downsample a timetable with the decimate function
%
% T_OUT = DECIMATE(T_IN, R)
%
% Downsample a timetable object with the DECIMATE function.
%
% See also: DECIMATE


newR = ceil(size(t_in,1)/R);

TDn = zeros(newR,size(t_in,2));

for i=1:size(t_in,2),
    TDn(:,i) = decimate(t_in{:,i},R);
end;

t_out = array2timetable(TDn,"RowTimes",t_in.Time(1:R:end),"VariableNames", t_in.Properties.VariableNames);
