use POSIX;
print strftime("%Y%m%dT%H%M%SZ", gmtime(time()));