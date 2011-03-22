package DaemonToolKit::Config;

use strict;
use warnings;

use Data::Dumper;
use Config::Tiny;
use DaemonToolKit::Validate;

sub new {
    my ($class, $file, $setup) = @_;

    # Parse file.
    my $cfg_orig = Config::Tiny->read($file)
      or die "Failed to read configuration from $file: \n" . Config::Tiny->errstr, "\n";
    my $s = {};

    # Validate each section
    while ( my ($val_section, $val_keys) = each %{ $setup } ) {
        if ( !defined $val_keys ) {
            $s->{$val_section} = $cfg_orig->{$val_section};
            next;
        }

        eval {
            $s->{$val_section} = DaemonToolKit::Validate->new($cfg_orig->{$val_section}, $val_keys);
        };
        if ( $@ ) {
            die "Error in configuration $file, section \"$val_section\": $@";
        }
    }
    
    bless $s, $class;
    return $s;
}

1;
