package DaemonToolKit;

use warnings;
use strict;

=head1 NAME

DaemonToolKit - A toolkit for building scalable daemons

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';


=head1 SYNOPSIS

Toolkit for quickly building single or multi process daemons in Perl, providing a consistent
user interface and several advanced features useful for scalability and long term reability.

=head1 PROVIDES

=over 2

=item * Command line handling and help

=item * Daemonization control (sysv style)

=item * Input validation

=item * Config file handling

=item * Daemon process watchdog support ("double fork")

=item * Change user and chroot

=item * Logging manager

=item * Multiprocess job manager with async queue operation

=item * Routing of jobs to different, independent worker groups

=item * Apache style 'elastic' preforking for worker processes

=item * Process recycling (limits impact of leaks), failure handling

=item * Retrieable queuing mechanism with optional adaptive backoff

=back

Perhaps a little code snippet.

    use DaemonToolKit;

    my $foo = DaemonToolKit->new();
    ...

=head1 EXPORT

A list of functions that can be exported.  You can delete this section
if you don't export anything, such as for a purely object-oriented module.

=head1 SUBROUTINES/METHODS

=head2 function1

=cut

sub function1 {
}

=head2 function2

=cut

sub function2 {
}

=head1 HISTORY

This toolkit was born in 2010, when working on a Managed File Transfer solution. The plumbing
seemed useful for other projects we had in the pipeline, so it got cleaned up a bit and made a
independent module.

=head1 AUTHOR

Andre Tomt, C<< <andre at tomt.net> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-daemontoolkit at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=DaemonToolKit>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc DaemonToolKit


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=DaemonToolKit>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/DaemonToolKit>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/DaemonToolKit>

=item * Search CPAN

L<http://search.cpan.org/dist/DaemonToolKit/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2011 Andre Tomt.

This library is free software; you can redistribute it and/or modify it under the terms of the GPL version 2.

See the LICENSE file for a copy of the GPL 2.

=cut

1; # End of DaemonToolKit
