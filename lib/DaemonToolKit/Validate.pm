package DaemonToolKit::Validate;

use strict;
use warnings;

use vars qw(@ISA @EXPORT);
require Exporter;
@ISA = qw(Exporter);

@EXPORT = qw(
  $IN_TYPE_STR
  $IN_TYPE_INT
  $IN_TYPE_OCT
  $IN_TYPE_BOOL
  $IN_TYPE_LIST
  $IN_TYPE_ENUM
  $IN_TYPE_ENUM_LIST
  $IN_TYPE_REGEX
  $IN_TYPE_ANY
);


our $IN_TYPE_STR       = 1;
our $IN_TYPE_INT       = 2;
our $IN_TYPE_OCT       = 3;
our $IN_TYPE_BOOL      = 4;
our $IN_TYPE_LIST      = 5;
our $IN_TYPE_ENUM      = 6;
our $IN_TYPE_ENUM_LIST = 7;
our $IN_TYPE_REGEX     = 8;
our $IN_TYPE_ANY       = 99;


sub new {
    my ($class, $data, $val_setup) = @_;
   
    my $self = {};
   
    ROW:
    while ( my ($val_key, $val_data) = each %{ $val_setup } ) {
        # Hands off!!
        if ( !defined $val_data && exists $data->{$val_key} ) {
            $self->{$val_key} = $data->{$val_key};
            next ROW;
        }
        
        # Shortcuts
        my $type     = $val_data->{'type'};
        my $required = $val_data->{'required'};
        my $default  = $val_data->{'default'};
        my $in       = $data->{$val_key};
        
        # Required
        if ( $required && !exists $data->{$val_key} ) {
            die "Required parameter \"$val_key\" is missing.\n";
        }
        
        # If we get undef/NULL in $in, and the default is undef, hands off.
        if ( !defined $in && !defined $default ) {
            $self->{$val_key} = $data->{$val_key};
            next ROW;
        }
        
        # Merge defaults directly (no use validating those!)
        # Note that the default format should match the desired output..
        if ( exists $val_data->{'default'} && !exists $data->{$val_key}  ) {
            $self->{$val_key} = $default;
            next ROW;
        }
        
        # Strings
        elsif ( $type == $IN_TYPE_STR ) {
            my $regex  = $val_data->{'regex'};
            my $strict = $val_data->{'strict'};
            
            if ( defined $regex && $in !~ /$regex/ ) {
                die "Parameter \"$val_key\" does not match regex $regex.\n";
            }
            elsif ( defined $strict && !grep { $_ eq $in } @{$strict} ) {
                die "Parameter \"$val_key\" does not match any in list: " . join(', ', @{$strict}) . "\n";
            }
            
            $self->{$val_key} = $in;
        }
        
        # Ints
        elsif ( $type == $IN_TYPE_INT ) {
            my $min = $val_data->{'min'};
            my $max = $val_data->{'max'};
            
            if ( $in =~ /^\d+$/ ) {
                $in = int($in);
                
                if ( defined $min && $in < $min ) {
                    die "Parameter \"$val_key\" integer value too low (min: $min)\n";
                }
                
                if ( defined $max && $in > $max ) {
                    die "Parameter \"$val_key\" integer value too high (max: $max)\n";
                }
                
                $self->{$val_key} = $in;
            }
        }
         
        # Bools
        elsif ( $type == $IN_TYPE_BOOL ) {
            if ( $in =~ /^(1|yes|on|true|enable)$/ ) {
                $self->{$val_key} = 1;
            }
            elsif ( $in =~ /^(0|no|off|false|disable)$/ ) {
                $self->{$val_key} = undef;
            }
            else {
                die "Parameter \"$val_key\" is not a valid boolean value.\n";
            }
        }
        
        # Octals (like permissions, umask)
        elsif ( $type == $IN_TYPE_OCT ) {
            if ( $in !~ /^\d+$/ ) {
                die "Parameter \"$val_key\" is not a valid octal value.\n";
            }
            
            $self->{$val_key} = oct($in);
        }
        
        # Array lists
        elsif ( $type == $IN_TYPE_LIST ) {
            my $sep     = $val_data->{'separator'};
            my @in_list = split($sep, $in);
            my @list;
            
            for my $entry ( @in_list ) {
                $entry =~ s/^\s+//;
                $entry =~ s/\s+$//;
                push @list, $entry;
            }
            
            $self->{$val_key} = \@list;
        }
        
        # Single enum values
        elsif ( $type == $IN_TYPE_ENUM ) {
            my $enums = $val_data->{'enum'};
            
            if ( !exists $enums->{$in} ) {
                die "Parameter \"$val_key\" has to be one of: " . join(', ', keys %{$enums}) . ". Supplied value is $in\n";
            }
            
            $self->{$val_key} = $enums->{$in};
        }
        
        # List enum values
        elsif ( $type == $IN_TYPE_ENUM_LIST ) {
            my $sep     = $val_data->{'separator'};
            my $enums   = $val_data->{'enum'};
            my @in_list = split($sep, $in);
            my @list;
            
            for my $entry ( @in_list ) {
                if ( !exists $enums->{$entry} ) {
                    die "Parameter \"$val_key\" has to be one or more of: " . join(', ', keys %{$enums}) . ". Supplied value is $in\n";
                }
                
                push @list, $enums->{$entry};
            }
            
            $self->{$val_key} = \@list;
        }
        
        # Regex, precompiled edition
        elsif ( $type == $IN_TYPE_REGEX ) {
            $self->{$val_key} = qr/$in/;
        }
        
        # No validation wanted! Yelp.
        elsif ( $type == $IN_TYPE_ANY ) {
            $self->{$val_key} = $in;
        }
        else {
            die "Internal consistency error: type $type not valid!";
        }
    }
    
    # Check for unknown inputs
    for my $key ( keys %{$data} ) {
        if ( ! exists $val_setup->{$key} ) {
            die "Unknown parameter $key.\n";
        }
    }

    #bless $self, $class;
    return $self; 
}

1;
