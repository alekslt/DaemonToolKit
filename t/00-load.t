#!perl -T

use Test::More tests => 1;

BEGIN {
    use_ok( 'DaemonToolKit' ) || print "Bail out!
";
}

diag( "Testing DaemonToolKit $DaemonToolKit::VERSION, Perl $], $^X" );
