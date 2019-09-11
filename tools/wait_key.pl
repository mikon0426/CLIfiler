use strict;
use POSIX qw(:termios_h);



my $g_termios = POSIX::Termios->new();
my $g_stdin = fileno( STDIN );
my $g_uname = `uname`;
my $g_stty_setting="";
$| = 1;

stty_save();
stty_unable();
while(1)
{
	my $key = wait_key();
	printf( "key(str)=[%s] key(int)=[%d]\n", $key, $key );
	if ( $key eq '^[' ) {
		last;
	}
}
stty_load();

exit(0);




sub stty_save
{
	$g_stty_setting=`stty -g`;
}

sub stty_unable
{
	`stty discard undef`;
	`stty eof undef`;
	`stty eol undef`;
	`stty eol2 undef`;
	`stty erase undef`;
	`stty intr undef`;
	`stty kill undef`;
	`stty lnext undef`;
	`stty quit undef`;
	`stty start undef`;
	`stty stop undef`;
	`stty susp undef`;
	`stty werase undef`;

	if ( $g_uname eq "Darwin" )
	{
		`stty dsusp undef`;
		`stty reprint undef`;
		`stty status undef`;
	}

	if ( $g_uname eq "Linux" )
	{
		`stty swtch undef`;
		`stty rprnt undef`;
	}
}

sub stty_load
{
	`stty $g_stty_setting`;
}

sub wait_key
{
	my $ret;

	$g_termios->getattr( $g_stdin );

	my $lflag_org = $g_termios->getlflag();
	my $cc_VMIN   = $g_termios->getcc(VMIN);
	my $cc_VTIME  = $g_termios->getcc(VTIME);

	my $lflag_wait = $lflag_org;
	$lflag_wait &= ~ICANON;
	$lflag_wait &= ~ECHO;
	$lflag_wait &= ~ECHOK;

	$g_termios->setlflag( $lflag_wait );
	$g_termios->setcc( VMIN, 1 );
	$g_termios->setcc( VTIME, 0 );
	$g_termios->setattr( $g_stdin, TCSANOW );

	my $len = sysread( STDIN, my $input, 256 );
	my $c = substr( $input, 0, 1 );
	my $c_sz = unpack( 'C*', $c );
    printf( "c=[%d] c_sz=[%s] len=[%d]\n", $c, $c_sz, $len );
	if ( $c_sz eq '27' ) {
		$ret = '^[' . substr( $input, 1, $len );
	}
	elsif ( $c_sz eq '8' ) {
		$ret = '^H';
	}
	elsif ( $c_sz eq '127' ) {
		$ret = '^[DEL';
	}
	elsif ( $c_sz eq '10' ) {
		$ret = "\n";
	}
	elsif ( $c_sz eq '9' ) {
		$ret = "\t";
	}
	elsif ( int($c_sz) < 27 ) {
		$ret = "d$c_sz";
	}
	else {
		$ret = $input;
	}

	$g_termios->setlflag($lflag_org);
	$g_termios->setcc( VMIN, $cc_VMIN );
	$g_termios->setcc( VTIME, $cc_VTIME );
	$g_termios->setattr( $g_stdin, TCSANOW );
	return $ret;

}

sub read_line
{

}
