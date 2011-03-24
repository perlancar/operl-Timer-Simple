# vim: set sw=2 sts=2 ts=2 expandtab smarttab:
package Timer::Simple;
# ABSTRACT: Small, simple timer (stopwatch) object

use strict;
use warnings;
use overload # core
  '""' => \&string,
  '0+' => \&elapsed,
  fallback => 1;

=method new

Constructor;  Takes a hash or hashref of arguments:

=for :list
* C<start> - Boolean; Defaults to true;
Set this to false to skip the initial setting of the clock.
You must call L</start> explicitly if you disable this.
* C<hires> - Boolean; Defaults to true;
Set this to false to not attempt to use L<Time::HiRes>
and just use L<time|perlfunc/time> instead.
* C<format> - Alternate C<sprintf> string; See L</hms>.

=cut

sub new {
  my $class = shift;
  my $self = {
    start => 1,
    hires => HIRES(),
    @_ == 1 ? %{$_[0]} : @_,
  };

  $self->{format} ||= default_format_spec($self->{hires});

  bless $self, $class;

  $self->start
    if $self->{start};

  return $self;
}

=method elapsed

Returns the number of seconds elapsed since the clock was started.

This method is used as the object's value when used in numeric context:

  $total_elapsed = $timer1 + $timer2;

=cut

sub elapsed {
  my ($self) = @_;

  if( !defined($self->{started}) ){
    # lazy load Carp since this is the only place we use it
    require Carp; # core
    Carp::croak("Timer never started!");
  }

  # if stop() was called, use that time, otherwise "now"
  my $elapsed = defined($self->{stopped})
    ? $self->{stopped}
    : $self->time;

  return $self->{hires}
    ? Time::HiRes::tv_interval($self->{started}, $elapsed)
    : $elapsed - $self->{started};
}

=method hms

  # list
  my @units = $timer->hms;
  sprintf("%d hours %minutes %f seconds", $timer->hms);

  # scalar
  print "took: " . $timer->hms . "\n"; # same as print "took :$timer\n";

  # alternate format
  $string = $timer->hms('%04dh %04dm %020.10f');

Separates the elapsed time (seconds) into B<h>ours, B<m>inutes, and B<s>econds.

In list context returns a three-element list (hours, minutes, seconds).

In scalar context returns a string resulting from
L<sprintf|perlfunc/sprintf_FORMAT,_LIST>
(essentially C<sprintf($format, $h, $m, $s)>).
The default format is
C<00:00:00.000000> (C<%02d:%02d:%9.6f>) with L<Time::HiRes> or
C<00:00:00> (C<%02d:%02d:%02d>) without.
An alternate C<format> can be specified in L</new>
or can be passed as an argument to the method.

=cut

sub hms {
  my ($self, $format) = @_;

  my ($h, $m, $s) = separate_hms($self->elapsed);

  return wantarray
    ? ($h, $m, $s)
    : sprintf(($format || $self->{format}), $h, $m, $s);
}

=method start
X<restart>

Initializes the timer to the current system time.

Aliased as C<restart>.

=cut

sub start {
  my ($self) = @_;

  # don't use an old stopped time if we're restarting
  delete $self->{stopped};

  $self->{started} = $self->time;
}

=method stop

Stop the timer.
This records the current system time in case you'd like to do more
processing (that you don't want timed) before reporting the elapsed time.

=cut

sub stop {
  my ($self) = @_;
  $self->{stopped} = $self->time;
  # natural return value would be elapsed() but don't compute it in void context
  return $self->elapsed
    if defined wantarray;
}

=method string

Returns the scalar (C<sprintf>) version of L</hms>.
This is the method called when the object is stringified (using L<overload>).

=cut

sub string {
  # this could be configurable: new(string => 'elapsed') # default 'hms'
  scalar $_[0]->hms;
}

=method time

Returns the current system time
using L<Time::HiRes/gettimeofday> or L<time|perlfunc/time>.

=cut

sub time {
  return $_[0]->{hires}
    ? [ Time::HiRes::gettimeofday() ]
    : time;
}

{
  # aliases
  no warnings 'once';
  *restart = \&start;
}

# package functions

=head1 FUNCTIONS

The following functions should not be necessary in most circumstances
but are provided for convenience to facilitate additional functionality.

They are not available for export (to avoid L<Exporter> overhead).
See L<Sub::Import> if you really want to import these methods.

=func HIRES

Indicates whether L<Time::HiRes> is available.

=cut

{
  # only perform the check once, but don't perform the check until required
  my $HIRES;
  sub HIRES () {
    $HIRES = (do { local $@; eval { require Time::HiRes; 1; } } || '')
      if !defined($HIRES);
    return $HIRES;
  }
}

=func default_format_spec

  $spec            = default_format_spec();  # consults HIRES()
  $spec_whole      = default_format_spec(0); # false forces integer
  $spec_fractional = default_format_spec(1); # true  forces fraction

Returns an appropriate C<sprintf> format spec according to the provided boolean.
If true,  the spec forces fractional seconds (floating point (C<%f>)).
If false, the spec forces seconds to an integer (whole number (C<%d>)).
If not specified the value of L</HIRES> will be used.

=cut

sub default_format_spec {
  my ($fractional) = @_ ? @_ : HIRES();
  # float: 9 (width) - 6 (precision) - 1 (dot) == 2 digits before decimal point
  return '%02d:%02d:' . ($fractional ? '%09.6f' : '%02d');
}

=func format_hms

  my $string = format_hms($hours, $minutes, $seconds);
  my $string = format_hms($seconds);

Format the provided hours, minutes, and seconds
into a string by guessing the best format.

If only seconds are provided
the value will be passed through L</separate_hms> first.

=cut

sub format_hms {
  # if only one argument was provided assume its seconds and split it
  my ($h, $m, $s) = (@_ == 1 ? separate_hms(@_) : @_);

  return sprintf(default_format_spec(int($s) != $s), $h, $m, $s);
}

=func separate_hms

  my ($hours, $minutes, $seconds) = separate_hms($seconds);

Separate seconds into hours, minutes, and seconds.
Returns a list.

=cut

sub separate_hms {
  my ($s)  = @_;

  # find the number of whole hours, then subtract them
  my $h  = int($s / 3600);
     $s -=     $h * 3600;
  # find the number of whole minutes, then subtract them
  my $m  = int($s / 60);
     $s -=     $m * 60;

  return ($h, $m, $s);
}

1;

=for :stopwords hms

=head1 SYNOPSIS

  use Timer::Simple ();
  my $t = Timer::Simple->new();
  do_something;
  print "something took: $t\n";

  # or take more control

  my $timer = Timer::Simple->new(start => 0);
    do_something_before;
  $timer->start;
    do_something_else;
  print "time so far: ", $t->elapsed, " seconds\n";
    do_a_little_more;
  print "time so far: ", $t->elapsed, " seconds\n";
    do_still_more;
  $timer->stop;
    do_something_after;
  printf "whole process lasted %d hours %d minutes %f seconds\n", $t->hms;

  $timer->restart; # use the same object to time something else

  # you can use package functions to work with mutliple timers

  $timer1 = Timer::Simple->new;
    do_stuff;
  $timer1->stop;
    do_more;
  $timer2 = Timer::Simple->new;
    do_more_stuff;
  $timer2->stop;

  print "first process took $timer1, second process took: $timer2\n";
  print "in total took: " . Timer::Simple::format_hms($timer1 + $timer2);

=head1 DESCRIPTION

This is a simple object to make timing an operation as easy as possible.

It uses L<Time::HiRes> if available (unless you tell it not to).

It stringifies to the elapsed time in an hours/minutes/seconds format
(default is C<00:00:00.000000> with L<Time::HiRes> or C<00:00:00> without).

This module aims to be small and efficient
and do what is useful in most cases,
while still offering some configurability to handle edge cases.

=head1 SEE ALSO

These are some other timers I found on CPAN
and how they differ from this module:

=for :list
* L<Time::Elapse> - eccentric API to a tied scalar
* L<Time::Progress> - Doesn't support L<Time::HiRes>
* L<Time::StopWatch> - tied scalar
* L<Dancer::Timer> - inside Dancer framework

=cut
