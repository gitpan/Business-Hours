package Business::Hours;
use strict;
require 5.006;
use Set::IntSpan;


use Time::Local qw/timelocal_nocheck/;

BEGIN {
	use Exporter ();
	use vars qw ($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
	$VERSION     = 0.01;
	@ISA         = qw (Exporter);
	#Give a hoot don't pollute, do not export more than needed by default
	@EXPORT      = qw ();
	@EXPORT_OK   = qw ();
	%EXPORT_TAGS = ();
}


########################################### main pod documentation begin ##
# Below is the stub of documentation for your module. You better edit it!


=head1 NAME

Business::Hours - 

=head1 SYNOPSIS

  use Business::Hours;
  my $hours = Business::Hours->new();    
  # Get a Set::IntSpan of all the business hours in the next week.
  # use the default business hours of 9am to 6pm localtime.
  $hours->business_hours_in_timespan(Start => time(), End => time()+(86400*7));

=head1 DESCRIPTION

This module is a simple tool for calculating business hours in a time period. 
Over time, additional functionality will be added to make it easy to calculate the number of
business hours between arbitrary dates. 


=head1 USAGE



=head1 BUGS

Yes

=head1 SUPPORT

Send email  to bug-business-hours@rt.cpan.org


=head1 AUTHOR

    Jesse Vincent
    Best Practical Solutions, LLC 
    jesse@cpan.org
    http://www.bestpractical.com

=head1 COPYRIGHT

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.


=head1 SEE ALSO

perl(1).

=cut

############################################# main pod documentation end ##


# Default business hours are weekdays from 9 am to 6pm
our $BUSINESS_HOURS = ({
        0 => { Name  => 'Sunday',
               Start => undef,
               End   => undef, },
        1 => { Name  => 'Monday',
               Start => '9:00',
               End   => '18:00', },
        2 => { Name  => 'Tuesday',
               Start => '9:00',
               End   => '18:00', },
        3 => { Name  => 'Wednesday',
               Start => '9:00',
               End   => '18:00', },
        4 => { Name  => 'Thursday',
               Start => '9:00',
               End   => '18:00', },
        5 => { Name  => 'Friday',
               Start => '9:00',
               End   => '18:00', },
        6 => { Name  => 'Saturday',
               Start => undef,
               End   => undef, }
      });



################################################ subroutine header begin ##

=head2 sample_function

 Usage     : How to use this function/method
 Purpose   : What it does
 Returns   : What it returns
 Argument  : What it wants to know
 Throws    : Exceptions and other anomolies
 Comments  : This is a sample subroutine header.
           : It is polite to include more pod and fewer comments.

See Also   : 

=cut

################################################## subroutine header end ##


sub new {
	my $class = shift;

	my $self = bless ({}, ref ($class) || $class);

	return ($self);
}

=head2 business_hours 

Set the business hours for this Business::Hours object.
Takes a hash of the form :

{
    0 => { Name => 'Sunday',
            Start => 'HH::MM',
               End => 'HH::MM'},

    1 => { Name => 'Monday',
            Start => 'HH::MM',
               End => 'HH::MM'},
    ....

    6 => { Name => 'Saturday',
            Start => 'HH::MM',
               End => 'HH::MM'},
    };

    Start and end times are of the form HH:MM.  Valid times are
    from 00:00 to 23:59.  If your hours are from 9am to 6pm, use
    Start => '9:00', End => '18:00'.  A given day MUST have a start
    and end time OR may declare both Start and End to be undef, if
    there are no valid hours on that day.

=cut

sub business_hours {
    my $self = shift;
    %{$self->{'business_hours'}} = (@_);

}



=head2 for_timespan

Takes a paramhash with the following parameters
	
	Start => The start of the period in question in seconds since the epoch
	End => The end of the period in question in seconds since the epoch

Returns a Set::IntSpan of business hours for this period of time.


=begin testing

use Business::Hours;
my $hours = Business::Hours->new();
my $hours_span = $hours->for_timespan(Start => time(), End => (time() + (86400 * 14)));


=end testing

=cut


sub for_timespan {
    my $self = shift;
    my %args = ( Start => undef,
                 End   => undef,
                 @_ );
    my $bizdays;
    if ( $self->{'business_hours'} ) {
        $bizdays = $self->{'business_hours'};
    }
    else {
        $bizdays = $BUSINESS_HOURS;
    }

    # Split the Start and End times into hour/minute specifications
    foreach my $day ( keys %$bizdays ) {
        my $day_href = $bizdays->{$day};
        foreach my $which qw(Start End) {
            if (    $day_href->{$which}
                 && $day_href->{$which} =~ /^(\d+)\D(\d+)$/ ) {
                $day_href->{ $which . 'Hour' }   = $1;
                $day_href->{ $which . 'Minute' } = $2;
            }
        }
    }

    # now that we know what the business hours are for each day in a week,
    # we need to find all the business hours in the period in question.

    # Create an intspan of the period in total.
    my $business_period =
      Set::IntSpan->new( $args{'Start'} . "-" . $args{'End'} );

    # jump back to the first day (Sunday) of the last week before the period
    # began.
    my @start        = localtime( $args{'Start'} );
    my $month        = $start[4];
    my $year         = $start[5];
    my $first_sunday = $start[3] - $start[6];

    # period_start is time_t at midnight local time on the first sunday
    my $period_start =
      timelocal_nocheck( 0, 0, 0, $first_sunday, $month, $year );


    # for each week until the end of the week in seconds since the epoch
    # is outside the business period in question
    my $week_start = $period_start;

    # @run_list is a run list of the period's business hours
    # its form is (<int>-<int2>,<int3>-<int4>)
    # For documentation about its format, have a look at Set::IntSpan.
    # (This is fed into Set::IntSpan to use to compute our actual run.
    my @run_list;

    while ( $week_start <= $args{'End'} ) {

        my @this_week_start = localtime($week_start);

        # foreach day in the week, find that day's business hours in
        # seconds since the epoch.
        for ( my $dow=0; $dow <= 6; $dow++ ) {

            my $day_hours = $bizdays->{$dow};
            if ( $day_hours->{'Start'} && $day_hours->{'End'} ) {
        
        # add the business seconds in that week to the runlist we'll use to 
        # figure out business hours
        # (Be careful to use timelocal to convert times in the week into actual
        # seconds, so we don't lose at DST transition)
                my $day_bizhours_start = timelocal_nocheck(
                                                 0,
                                                 $day_hours->{'StartMinute'},
                                                 $day_hours->{'StartHour'},
                                                 ( $this_week_start[3] + $dow ),
                                                 $this_week_start[4],
                                                 $this_week_start[5] );
                my $day_bizhours_end = timelocal_nocheck(0,
                                                 $day_hours->{'EndMinute'},
                                                 $day_hours->{'EndHour'},
                                                 ( $this_week_start[3] + $dow ),
                                                 $this_week_start[4],
                                                 $this_week_start[5] );

                push (@run_list , "$day_bizhours_start-$day_bizhours_end");

            }


        }


        # now that we're done with this week, calculate the start of the next week
        # the next week starts at midnight on the sunday following the previous
        # sunday
        $week_start = timelocal_nocheck( 0, 0, 0, ( $this_week_start[3] + 7 ),
                                     $this_week_start[4], $this_week_start[5] );

    }

    my $business_hours = Set::IntSpan->new(join(',',@run_list));
    my $business_hours_in_period = $business_hours->intersect($business_period);


    # find the intersection of the business period intspan and the  business
    # hours intspan. (Because we want to trim any business hours that fall
    # outside the business period)

    # TODO: Remove any holidays from the business hours

    # TODO: Add any special times to the business hours

    # Return the intspan of business hours.

    return ($business_hours_in_period);

}




1; #this line is important and will help the module return a true value
__END__

