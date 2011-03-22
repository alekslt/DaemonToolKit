package DaemonToolKit::Logger;

use strict;
use warnings;

use IO::Handle;
use Fcntl ':flock';
use List::Util qw(min);

use vars qw(@ISA @EXPORT);
require Exporter;
@ISA = qw(Exporter);

@EXPORT = qw(
  $log

  $LOG_DEBUG
  $LOG_DETAIL
  $LOG_INFO
  $LOG_WARN
  $LOG_ERR
);

our $LOG_DEBUG  = 0;
our $LOG_DETAIL = 1;
our $LOG_INFO   = 2;
our $LOG_WARN   = 3;
our $LOG_ERR    = 4;

# Common object shared with other namespaces for general logging. Sort of singleton.
our $log = DaemonToolKit::Logger->new;

# Storage for log messages until logfile gets enabled.
my @cache;

sub new {
    my ($class) = @_;
    my @prefix = ();
    
    my $s = bless {
        terminal     => 1,
        terminal_lvl => $LOG_DETAIL,
        logfile      => undef,
        logfile_lvl  => $LOG_INFO,
        logfile_fd   => undef,
        logfiledir   => undef,
        prefix       => \@prefix,
        instance     => undef,
        applprefix   => '',
    } => $class;
    
    return $s;
}

sub global_level {
    my ($s, $level) = @_;
    
    if ( defined $level ) {
        $s->{terminal_lvl} = $level;
        $s->{logfile_lvl}  = $level;
        return $level;
    }
    
    # Return the lowest level
    return min ($s->{terminal_lvl}, $s->{logfile_lvl});
}

sub terminal_level {
	my ($s, $level) = @_;
	
	if ( defined $level ) {
	    $s->{terminal_lvl} = $level;
	    return $level;
    }
	
	return $s->{terminal_lvl};
}

sub logfile_level {
	my ($s, $level) = @_;
	
	if ( defined $level ) {
	    $s->{logfile_lvl} = $level;
	    return $level;
	}
	
	return $s->{logfile_lvl};
}

sub logfile_enable {
    my ($self, $logname) = @_;
    my $logdir = $self->{'logfiledir'};
    my $path   = "$logdir/${logname}.log";
    
    open my $logfd, '>>', $path
      or die "Failed opening logfile $path for writing: $!\n";
    
    $self->{'logfile'} = $logname;
    $self->{'logfile_fd'} = $logfd;
    
    # Flush log cache
    my $old_term = $self->{'terminal'};
    $self->{'terminal'} = 0;
    while ( my $entry = shift @cache ) {
        $self->out($entry->{'level'}, $entry->{'msg'});
    }
    $self->{'terminal'} = $old_term;
}

sub logfile_disable {
    my ($self) = @_;
    
    close $self->{'logfile_fd'};
    $self->{'logfile'} = undef;
    $self->{'logfile_fd'} = undef;
}

sub logfile_dir {
    my ($self, $dir) = @_;
    $self->{'logfiledir'} = $dir;
}

sub reopen {
    my ($self) = @_;
    my $logname = $self->{'logfile'};
    my $logfd   = $self->{'logfile_fd'};
    
    close $logfd;
    $self->logfile_enable($logname);
    
    $self->out($LOG_INFO, "reopened logfile");
}

##
## Writes log output to log files, terminal and handles locking
##
sub out {
    my ($self, $level, $msg) = @_;
    
    my $logfile      = $self->{'logfile'};
    my $logfile_lvl  = $self->{'logfile_lvl'};
    my $terminal     = $self->{'terminal'};
    my $terminal_lvl = $self->{'terminal_lvl'};
    
    # Buffer if logfile is disabled
    if ( !$logfile ) {
        push @cache, { 'level' => $level, 'msg' => $msg };
    }

    # Determine what we're going to log to, depending on set levels
    my $log_to_term = undef;
    my $log_to_file = undef;

    if ( $terminal && $terminal_lvl <= $level ) {
    	$log_to_term = 1;
    }
    
    if ( $logfile && $logfile_lvl <= $level ) {
    	$log_to_file = 1;
    }
   
    # If we don't have anything to do, return early.
    if ( !$log_to_file && !$log_to_term ) {
    	return 1;
    }
	
    my $time        = localtime;
    my $logfile_fd  = $self->{'logfile_fd'};
    my $prefix      = $self->{'prefix'};
    my $applprefix  = $self->{'applprefix'};
    my $levelprefix;
    my $realprefix  = '';
    chomp $msg;
    
    if ( @{$prefix} > 0 ) {
        $realprefix = join(': ', @{$prefix}) . ': ';
    }
    
    # Sort of ugly
    if ( $level == $LOG_DEBUG ) {
        $levelprefix = 'DEBUG  ';
    }
    elsif ( $level == $LOG_DETAIL ) {
        $levelprefix = 'DETAIL ';
    }
    elsif ( $level == $LOG_INFO ) {
        $levelprefix = 'INFO   ';
    }
    elsif ( $level == $LOG_WARN ) {
        $levelprefix = 'WARN   ';
    }
    elsif ( $level == $LOG_ERR ) {
        $levelprefix = 'ERROR  ';
    }
    
    # Lock logfile, and make sure we are at EOF when getting the lock.
    if ( $log_to_file ) {
        flock $logfile_fd, LOCK_EX
          or die "failed aquiring lock for $logfile: $!\n";
        seek $logfile_fd, 0, 2;
    }
    
    foreach my $line ( split("\n", $msg) ) {
        if ( $log_to_term ) {
            if ( $level >= $LOG_WARN ) {
                print STDERR '[', $time, "] ", $applprefix, $levelprefix, $realprefix, $line, "\n";
            }
            else {
                print STDOUT '[', $time, "] ", $applprefix, $levelprefix, $realprefix, $line, "\n";
            }
        }
        
        if ( $log_to_file ) {
            print {$logfile_fd} '[', $time, '] ', $levelprefix, $realprefix, $line, "\n";
        }
    }
    
    # Unlock logfile (in perl, this also flushes the filehandle)
    if ( $log_to_file ) {
        flock $logfile_fd, LOCK_UN;
    }
}

sub applprefix {
    my ($s, $newprefix) = @_;
    $s->{'applprefix'} = $newprefix;
}

sub prefix_push {
    my ($s, $newprefix) = @_;
    my $prefix = $s->{'prefix'};
    push @{$prefix}, $newprefix;
}

sub prefix_pop {
    my ($s) = @_;
    my $prefix = $s->{'prefix'};
    pop @{$prefix};
}

sub finish {
    my ($self) = @_;
    
    if ( $self->{'logfile_fd'}) {
        close $self->{'logfile_fd'};
    }
}

1;
