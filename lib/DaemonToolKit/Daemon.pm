package DaemonToolKit::Daemon;

use warnings;
use strict;
use feature qw(say switch);
use Carp;
use POSIX qw(setsid);
use Getopt::Long;
use Sys::Hostname;
use FindBin;
use DaemonToolKit::Validate;
use DaemonToolKit::Config;
use DaemonToolKit::Logger;
use Data::Dumper;

my $configargs_core = {
    'system'  => {
        'hostname' => {
            'required'  => 0,
            'type'      => $IN_TYPE_STR,
            'default'   => hostname(),
            'regex'     => '^[\w\-\_]+$',
        },
        'user' => {
            'required'  => 0,
            'type'      => $IN_TYPE_STR,
            'default'   => undef,
            'regex'     => '^[\w\-\_]+$',
        },
        'group' => {
            'required'  => 0,
            'type'      => $IN_TYPE_STR,
            'default'   => undef,
            'regex'     => '^[\w\-\_]+$',
        },
        'logdir' => {
            'required'  => 0,
            'type'      => $IN_TYPE_STR,
            'default'   => '%LOGDIR%',
        },
        'rundir' => {
            'required'  => 0,
            'type'      => $IN_TYPE_STR,
            'default'   => '%RUNDIR%',
        },
        'loghandler' => {
            'required'  => 0,
            'type'      => $IN_TYPE_ENUM,
            'default'   => 'syslog',
            'enum'      => { 'syslog' => 'syslog', 'file' => 'file' },
        },
        'syslogfacility' => {
            'required'  => 0,
            'type'      => $IN_TYPE_ENUM,
            'default'   => 'daemon',
            'enum'      => {
                'auth'     => 'auth',
                'authpriv' => 'auth',
                'cron'     => 'cron',
                'daemon'   => 'daemon',
                'kern'     => 'kern',
                'lpr'      => 'lpr',
                'mail'     => 'mail',
                'news'     => 'news',
                'user'     => 'user',
                'uucp'     => 'uucp',
                'local0'   => 'local0',
                'local1'   => 'local1',
                'local2'   => 'local2',
                'local3'   => 'local3',
                'local4'   => 'local4',
                'local5'   => 'local5',
                'local6'   => 'local6',
                'local7'   => 'local7',
            },
        }
    },
};

sub new {
    my ($class, %opts) = @_;
    my $procname   = $opts{procname};
    my $configargs = $opts{configargs};
    my $foreground = 0;
    my $debug      = 0;
    # XXX Use a search path for FHS compliance
    my $cfile      = "$FindBin::Bin/../conf/$procname.cf";
    my $pidfile    = "$FindBin::Bin/../run/pid";
    
    # Compose list of standard options and add the supplied ones to it
    my @cmdargs = (
        ['foreground', \$foreground, '-f, --foreground', 'Run in the foreground (don\'t detach)'],
        ['config=s',   \$cfile,      '-c, --config',     "Specify configuration file (defaults to $cfile)"],
        ['debug',      \$debug,      '-d, --debug',      'Enable debugging output'],
        ['help',       \&show_help,  undef,              undef]
    );
    
    if ( $opts{cmdargs} ) {
        for my $arg ( @{$opts{cmdargs}} ) {
            push @cmdargs, $arg;
        }
    }
    
    # Make it suitable for Getopt::Long, and invoke it
    my @getopt;
    for my $opt ( @cmdargs ) {
        my @a = @$opt;
        push @getopt, $a[0], $a[1];
    }
    GetOptions(@getopt);
    
    if ( $debug ) {
        $log->global_level($LOG_DEBUG);
    }
    
    # Load configuration
    while ( my ($core_grp, $core_data) = each %$configargs_core ) {
        if ( exists $configargs->{$core_grp} ) {
            croak "configargs conflicts with DaemonToolKit built-ins.";
        }
        
        $configargs->{$core_grp} = $core_data;
    }
    
    my $cf = DaemonToolKit::Config->new($cfile, $configargs);
    
    my $s = bless {
      cmdargs    => \@cmdargs,
      foreground => $foreground,
      pidfile    => $pidfile,
      procname   => $procname,
      cf         => $cf
    } => $class;
    
    given (shift @ARGV) {
        when ('start') {
            $s->cmd_start;
        }
        when ('stop') {
            $s->cmd_stop;
        }
        when ('reload') {
            $s->cmd_reload;
        }
        when ('restart') {
            $s->cmd_restart;
        }
        when ('status') {
            $s->cmd_status;
        }
        when ('version') {
            say STDERR "$procname $main::VERSION";
            exit 0;
        }
        default {
            $s->show_help;
        }
    }

    return $s;
}

sub show_help {
    my ($s) = @_;
    my $procname = $s->{procname};
    my @cmdargs  = @{$s->{cmdargs}};    
    
    say STDERR 'Usage:';
    say STDERR "  $procname [options] { start | stop | reload | restart | status | version }\n";
    say STDERR 'Options:';    
    
    for my $arg ( @cmdargs ) {
        my @a = @$arg;
        next if !$a[2];
        
        say STDERR '   ', $a[2];
        if ( $a[3] ) {
            say STDERR '      ', $a[3];
        }
        say STDERR '';
    }
    
    exit 0;
}

sub cmd_restart {
    my ($s) = @_;
    $s->cmd_stop(noexit => 1);
    $s->cmd_start;
}

sub cmd_start {
    my ($s) = @_;
    my $procname = $s->{procname};
    my $wsetup   = $s->{workers};
    my $cb_load  = $s->{cb_load};
    local $|;
    $| = 1;
    
    # XXX Make sure we're starting as root - or the configured user.
    
    # Background ourselfes
    $log->out($LOG_DEBUG, "Checking for running process..");
    if ( my $mgrpid = $s->check_pid_running ) {
        die "There appears to be running a $procname daemon (pid $mgrpid) already. Bailing.\n";
    }
   
    print "Starting $procname.. ";

    # Enable logging to file
    $log->logfile_dir($s->{cf}->{system}->{logdir});
    $log->logfile_enable($procname);
    
    # Deamonize
    $s->background;
    #$s->write_pid;
    $s->change_root;
    $s->drop_privs;

    $log->out($LOG_INFO, "Starting..");

    #$log->out($LOG_INFO, "Started $procname $main::VERSION");
}

sub cmd_stop {
    my ($s, %opts) = @_;
    my $noexit   = $opts{noexit} || 0;
    my $procname = $s->{procname};    
    
    local $|;
    $| = 1;
    
    my $mgrpid = $s->check_pid_running
      or die "Daemon does not appear to be running.\n";
    
    print "Stopping $procname.. ";
    kill 15, $mgrpid or croak "Error signalling daemon: $!";
    
    my $i = 0;
    while ( 1 ) {
        $i++;
        
        sleep 0.5 if $i == 1;
        if ( !$s->check_pid_running ) {
            say 'stopped';
            last;
        }
        
        if ( $i > 15 ) {
            die "Timed out waiting for daemon to exit.\n";
        }
        
        sleep 2;
    }
    
    exit 0 if !$noexit;
}

sub cf {
    my ($s) = @_;
    return $s->{cf};
}

sub background {
    my ($s) = @_;
    my $foreground = $s->{foreground};
    my $procname   = $s->{procname};
    $0 = "$procname";
    
    if ( $foreground ) {
        $s->write_pid($$);
        say 'started.';
        return;
    }
    
    $log->out($LOG_DEBUG, "Daemonizing");
    defined (my $pid = fork) or die "Error forking process: $!";
    if ( $pid ) {
        # Parent, report and exit
        $s->write_pid($pid);
        say 'started.';
        exit 0;
    }
    
    chdir '/' or die "Error changing working directory to /: $!\n";
    setsid()  or die "Error starting new session: $!";
    open (STDIN , '/dev/null')  or die "Can't read /dev/null: $!";
    open (STDOUT, '>/dev/null') or die "Can't write to /dev/null: $!";
    open (STDERR, '>/dev/null') or die "Can't write to /dev/null: $!";
    
    return 1;
}

sub change_root {

}

sub drop_privs {
    
}

sub write_pid {
    my ($s, $pid) = @_;
    my $pidfile = $s->{pidfile};
    open my $fh, '>', $pidfile or die "Error opening $pidfile for writing: $!";
    print $fh "$pid" or die "Error writing to pidfile $pidfile: $!";
    close $fh;
}

sub get_pid {
    my ($s) = @_;
    my $pidfile = $s->{pidfile};
    return 0 if ! -r $pidfile;
    
    open my $fh, '<', $pidfile or die "Cannot open pidfile $pidfile for reading: $!";
    my $line = <$fh>;
    close $fh;
    
    if ( $line =~ /^(\d+)$/ ) {
        return $1;
    }
    
    return 0;
}

sub check_pid_running {
    my ($s) = @_;
    
    my $pid = $s->get_pid;
    if ( -d "/proc/$pid" ) {
        # Running
        # XXX also check uid and name using status?
        return $pid;
    }
    
    return;
}

sub unlink_pid {
    my ($s) = @_;
    my $pidfile = $s->{pidfile};
    unlink $pidfile or die "Error removing pidfile $pidfile: $!";
}

1;
