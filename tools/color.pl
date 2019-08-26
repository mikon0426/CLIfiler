


for( my $i=0; $i<256; $i++ )
{
	printf( "\e[48;5;%dm %03d \e[m", $i, $i );

	my $n = ($i+1) % 10;
	if ( $n == 0 ) {
		printf( "\n" );
	}
}

printf( "\n" );

for( my $i=0; $i<256; $i++ )
{
	printf( "\e[38;5;%dm %03d \e[m", $i, $i );

	my $n = ($i+1) % 10;
	if ( $n == 0 ) {
		printf( "\n" );
	}
}

