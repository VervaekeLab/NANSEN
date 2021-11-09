function str = dateformat2expression(str)

% Todo...

str = strrep(str, 'yyyy', '\d{4}');
str = strrep(str, 'yy', '\d{2}');


str = strrep(str, 'mm', '\d{2}');
str = strrep(str, 'dd', '\d{2}');

end
