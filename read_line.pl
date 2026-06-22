use strict;
use FindBin;
use lib "$FindBin::Bin";
require "read_line.pm";



ReadLine::stty_save();
ReadLine::stty_unable();
while(1)
{
	my $key = ReadLine::read_line( "input=", "q" );
	printf( "\nkey(str)=[%s] key(int)=[%d]\n", $key, $key );
	if ( $key eq '^[' ) {
		last;
	}
	if ( $key eq 'q' ) {
		last;
	}
}
ReadLine::stty_load();

exit(0);



