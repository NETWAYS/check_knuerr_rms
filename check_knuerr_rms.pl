#!/usr/bin/perl -w

# ------------------------------------------------------------------------------
# check_knuerr_rms.pl - checks the knuerr_rms environmental devices.
# Copyright (C) 2009  NETWAYS GmbH, www.netways.de
# Author: Michael Streb <michael.streb@netways.de>
# Author: Birger Schmidt <birger.schmidt@netways.de>
# Version: $Id: 69a2b16d259d09f34992bfaedf00f611eefa0853 $
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
# $Id: 69a2b16d259d09f34992bfaedf00f611eefa0853 $
# ------------------------------------------------------------------------------

# basic requirements
use strict;
use Getopt::Long;
use File::Basename;
use Pod::Usage;
use Net::SNMP;

# predeclared subs
use subs qw/print_help/;

# predeclared vars
use vars qw (
  $PROGNAME
  $VERSION

  %states
  %state_names

  $opt_host
  $opt_community
  $opt_input
  $opt_warning
  $opt_critical

  $opt_help
  $opt_man
  $opt_verbose
  $opt_version

  $cont_sensor
  $tha_sensor

  $input_name
  $input_type
  $input_value
  $input_normal_value

  $opt_clamp
  $clamp_voltage
  $clamp_current
  $clamp_kwatts
  $clamp_kva
  $clamp_energy

  $session
  $error
);

# Main values
$PROGNAME = basename($0);
$VERSION  = '1.2';

# Nagios exit states
%states = (
	OK       => 0,
	WARNING  => 1,
	CRITICAL => 2,
	UNKNOWN  => 3
);

# Nagios state names
%state_names = (
	0 => 'OK',
	1 => 'WARNING',
	2 => 'CRITICAL',
	3 => 'UNKNOWN'
);

$tha_sensor = 0;
$cont_sensor = 0;
$opt_warning = "null";
$opt_critical = "null";

# SNMP

my $opt_community = "public";
my $snmp_version  = "2c";

my $response;

# type definitions
my %tha_types = (
	2 => {
		'name' => 'temperature',
		'unit' => 'temp'
	},
	3 => {
		'name' => 'humidity',
		'unit' => '%'
	},
	4 => {
		'name' => 'analogue',
		'unit' => 'volts'
	},
	5 => {
		'name' => 'contact',
		'unit' => ''
	},
	255 => {
		'name' => 'inactive',
		'unit' => ''
	}
);
my %tha_temp_scale = (
	1 => 'C',
	2 => 'F',
	3 => 'K',
);
# OID's for RMS
my @oids;

my $tha_scale	= ".1.3.6.1.4.1.3711.24.1.1.1.2.1.0";
my $tha_chan	= ".1.3.6.1.4.1.3711.24.1.1.1.2.2.1.1";
my $tha_name	= ".1.3.6.1.4.1.3711.24.1.1.1.2.2.1.3";
my $tha_type	= ".1.3.6.1.4.1.3711.24.1.1.1.2.2.1.6";
my $tha_value	= ".1.3.6.1.4.1.3711.24.1.1.1.2.2.1.7";

my $cont_chan	= ".1.3.6.1.4.1.3711.24.1.1.1.3.1.1.1";
my $cont_name	= ".1.3.6.1.4.1.3711.24.1.1.1.3.1.1.3";
my $cont_normal_state	= ".1.3.6.1.4.1.3711.24.1.1.1.3.1.1.6";
my $cont_current_state	= ".1.3.6.1.4.1.3711.24.1.1.1.3.1.1.7";

# OID's for DI-View
my $diview 		= ".1.3.6.1.4.1.3711.24.1.1.98.1.0";
my $diview_voltage	= ".1.3.6.1.4.1.3711.24.1.1.7.3.1.1.3";
my $diview_voltage_ucl	= ".1.3.6.1.4.1.3711.24.1.1.7.3.2.1.3";
my $diview_voltage_uwl	= ".1.3.6.1.4.1.3711.24.1.1.7.3.2.1.4";
my $diview_voltage_lwl	= ".1.3.6.1.4.1.3711.24.1.1.7.3.2.1.5";
my $diview_voltage_lcl	= ".1.3.6.1.4.1.3711.24.1.1.7.3.2.1.6";
my $diview_current	= ".1.3.6.1.4.1.3711.24.1.1.7.3.1.1.4";
my $diview_current_ucl	= ".1.3.6.1.4.1.3711.24.1.1.7.3.2.1.7";
my $diview_current_uwl	= ".1.3.6.1.4.1.3711.24.1.1.7.3.2.1.8";
my $diview_current_lwl	= ".1.3.6.1.4.1.3711.24.1.1.7.3.2.1.9";
my $diview_current_lcl	= ".1.3.6.1.4.1.3711.24.1.1.7.3.2.1.10";
my $diview_kwatts	= ".1.3.6.1.4.1.3711.24.1.1.7.3.1.1.7";
my $diview_kwatts_ucl	= ".1.3.6.1.4.1.3711.24.1.1.7.3.2.1.17";
my $diview_kwatts_uwl	= ".1.3.6.1.4.1.3711.24.1.1.7.3.2.1.18";
my $diview_kwatts_lwl	= ".1.3.6.1.4.1.3711.24.1.1.7.3.2.1.19";
my $diview_kwatts_lcl	= ".1.3.6.1.4.1.3711.24.1.1.7.3.2.1.20";
my $diview_kva		= ".1.3.6.1.4.1.3711.24.1.1.7.3.1.1.6";
my $diview_kva_ucl	= ".1.3.6.1.4.1.3711.24.1.1.7.3.2.1.13";
my $diview_kva_uwl	= ".1.3.6.1.4.1.3711.24.1.1.7.3.2.1.14";
my $diview_kva_lwl	= ".1.3.6.1.4.1.3711.24.1.1.7.3.2.1.15";
my $diview_kva_lcl	= ".1.3.6.1.4.1.3711.24.1.1.7.3.2.1.16";
my $diview_energy	= ".1.3.6.1.4.1.3711.24.1.1.7.3.1.1.5";
my $diview_energy_ucl	= ".1.3.6.1.4.1.3711.24.1.1.7.3.2.1.11";
my $diview_energy_uwl	= ".1.3.6.1.4.1.3711.24.1.1.7.3.2.1.12";

# Get the options from cl
Getopt::Long::Configure('bundling');
GetOptions(
	'h'       => \$opt_help,
	'H=s'     => \$opt_host,
	'C=s',    => \$opt_community,
	'I=n',    => \$opt_input,
	'clamp=n',    => \$opt_clamp,
	'w=s'     => \$opt_warning,
	'c=s'     => \$opt_critical,
	'man'     => \$opt_man,
	'verbose' => \$opt_verbose,
	'V'		  => \$opt_version
  )
  || print_help( 1, 'Please check your options!' );

# If somebody wants to the help ...
if ($opt_help) {
	print_help(1);
}
elsif ($opt_man) {
	print_help(99);
}elsif ($opt_version) {
	print_help(-1);
}

# Check if all needed options present.
unless ( $opt_host && ( $opt_input || $opt_clamp )) {

	print_help( 1, 'Not enough options specified!' );
}
else {

	# Open SNMP Session
	( $session, $error ) = Net::SNMP->session(
		-hostname  => $opt_host,
		-community => $opt_community,
		-port      => 161,
		-version   => $snmp_version,
	);

	# SNMP Session failed
	if ( !defined($session) ) {
		print $state_names{ ( $states{UNKNOWN} ) } . ": $error";
		exit $states{UNKNOWN};
	}

	if ($opt_input) {
		# get sensor informations (tha or contact tree)
		my $response_scale = $session->get_request($tha_scale);
		my $response_tha = $session->get_request($tha_chan.".".$opt_input);
		my $response_cont = $session->get_request($cont_chan.".".$opt_input);
		if ( $response_tha->{$tha_chan.".".$opt_input} =~ m/(\d+)/ ) {
			$tha_sensor = 1;
			$tha_types{2}->{'unit'} = $tha_temp_scale{$response_scale->{$tha_scale}};
			$response = $response_tha;
		} else {
			if ( $response_cont->{$cont_chan.".".$opt_input} =~ m/(\d+)/ ) {
				$cont_sensor = 1;
				$response = $response_cont;
			} else {
				print "No sensor found on Input $opt_input\n";
				exit ( $states{UNKNOWN} );
			}
		}		

		# check which Input is installed and get the values
		if ($tha_sensor == 1) {
			push (@oids, $tha_name.".".$opt_input);
			push (@oids, $tha_type.".".$opt_input);
			push (@oids, $tha_value.".".$opt_input);
			$response = $session->get_request(@oids);
		} else {
			if ($cont_sensor == 1) {
				push (@oids, $cont_name.".".$opt_input);
				push (@oids, $cont_normal_state.".".$opt_input);
				push (@oids, $cont_current_state.".".$opt_input);
				$response = $session->get_request(@oids);
			} else {
				print "No suitable Values found for Input $opt_input\n";
				exit ( $states{UNKNOWN} );
			}
		}	
	} else {
		# check for diview
		if ($opt_clamp) {
			$response = $session->get_request($diview);
			if ($response->{$diview} =~ m/powerhawk/i) {
				push (@oids, $diview_voltage.".".$opt_clamp);
				push (@oids, $diview_voltage_ucl.".".$opt_clamp);
				push (@oids, $diview_voltage_uwl.".".$opt_clamp);
				push (@oids, $diview_voltage_lwl.".".$opt_clamp);
				push (@oids, $diview_voltage_lcl.".".$opt_clamp);
				push (@oids, $diview_current.".".$opt_clamp);
				push (@oids, $diview_current_ucl.".".$opt_clamp);
				push (@oids, $diview_current_uwl.".".$opt_clamp);
				push (@oids, $diview_current_lwl.".".$opt_clamp);
				push (@oids, $diview_current_lcl.".".$opt_clamp);
				push (@oids, $diview_kwatts.".".$opt_clamp);
				push (@oids, $diview_kwatts_ucl.".".$opt_clamp);
				push (@oids, $diview_kwatts_uwl.".".$opt_clamp);
				push (@oids, $diview_kwatts_lwl.".".$opt_clamp);
				push (@oids, $diview_kwatts_lcl.".".$opt_clamp);
				push (@oids, $diview_kva.".".$opt_clamp);
				push (@oids, $diview_kva_ucl.".".$opt_clamp);
				push (@oids, $diview_kva_uwl.".".$opt_clamp);
				push (@oids, $diview_kva_lwl.".".$opt_clamp);
				push (@oids, $diview_kva_lcl.".".$opt_clamp);
				push (@oids, $diview_energy.".".$opt_clamp);
				push (@oids, $diview_energy_ucl.".".$opt_clamp);
				push (@oids, $diview_energy_uwl.".".$opt_clamp);
				$response = $session->get_request(@oids);
			} else { 
				print "No Di-View found on $opt_host";
				exit ( $states{UNKNOWN} );
			}
		}
	}

	#close SNMP
	$session->close();
		
	# get the values for specified port
	foreach (@oids) {
		if ($opt_input) {
			if ($tha_sensor == 1 ) {
				$input_name = $response->{$tha_name.".".$opt_input};
				$input_type = $response->{$tha_type.".".$opt_input};
				$input_value = $response->{$tha_value.".".$opt_input}/10;
			} else {
				if ( $cont_sensor == 1 ) {
					$input_name = $response->{$cont_name.".".$opt_input};
					$input_normal_value = $response->{$cont_normal_state.".".$opt_input};
					$input_value = $response->{$cont_current_state.".".$opt_input};
				} else {
					print "No suitable values found for input $opt_input\n";
					exit ( $states{UNKNOWN} );
				}
			}
		} else { 
			# check for diview
			if ($opt_clamp) {
				$clamp_voltage = $response->{$diview_voltage.".".$opt_clamp};	
				# check for valid value and exising clamp
				if ($clamp_voltage =~ m/(\d+)/) {	
					$clamp_current = $response->{$diview_current.".".$opt_clamp};
					$clamp_kwatts = $response->{$diview_kwatts.".".$opt_clamp};	
					$clamp_kva = $response->{$diview_kva.".".$opt_clamp};	
					$clamp_energy = $response->{$diview_energy.".".$opt_clamp};
				} else {
					print "No suitable values found for clamp $opt_clamp\n";
					exit ( $states{UNKNOWN} );
				}
			}
		}
	}	
	
	# set the properties for installed input module
	if ($input_value) {
		if ($tha_sensor == 1) {
			if ($opt_critical =~ m/(\d+)/ && $input_value >= $opt_critical) {
				print "CRITICAL: Input $opt_input, $input_name ($tha_types{$input_type}->{'name'}) is at ${input_value}$tha_types{$input_type}->{'unit'}|$tha_types{$input_type}->{'name'}=${input_value}$tha_types{$input_type}->{'unit'};$opt_warning;$opt_critical\n";
				exit ( $states{CRITICAL} );
			} else {
				if ($opt_warning =~ m/(\d+)/ && $input_value >= $opt_warning) {
					print "WARNING: Input $opt_input, $input_name ($tha_types{$input_type}->{'name'}) is at ${input_value}$tha_types{$input_type}->{'unit'}|$tha_types{$input_type}->{'name'}=${input_value}$tha_types{$input_type}->{'unit'};$opt_warning;$opt_critical\n";
					exit ( $states{WARNING} );
				} else {
					print "OK: Input $opt_input, $input_name ($tha_types{$input_type}->{'name'}) is at ${input_value}$tha_types{$input_type}->{'unit'}|$tha_types{$input_type}->{'name'}=${input_value}$tha_types{$input_type}->{'unit'};$opt_warning;$opt_critical\n";
					exit ( $states{OK} );
				}
			}
		} else { 
			if ($cont_sensor == 1) {
				if ($input_normal_value != $input_value) {
					print "CRITICAL: error on Input $opt_input, $input_name is $input_value normal would be $input_normal_value\n";
					exit ( $states{CRITICAL} );
				} else {
					print "OK: Input $opt_input, $input_name is $input_value normal is $input_normal_value\n";
					exit ( $states{OK} );
				}
			}
		}
	} else {
		if ($opt_clamp) {
			my $output = "";
			my $error_level = "OK";
			
			# check voltage thresholds
			if ($clamp_voltage >= $response->{$diview_voltage_ucl.".".$opt_clamp} || $clamp_voltage <= $response->{$diview_voltage_lcl.".".$opt_clamp}) {
				$output = "voltage CRITICAL: $clamp_voltage, ";
				$error_level = "CRITICAL";
			} else {
				if ($clamp_voltage >= $response->{$diview_voltage_uwl.".".$opt_clamp} || $clamp_voltage <= $response->{$diview_voltage_lwl.".".$opt_clamp}) {
					$output = "voltage WARNING: $clamp_voltage, ";
					$error_level = "WARNING";
				} else {
					$output = "voltage OK: $clamp_voltage, ";
				}
			}

			# get the right decimal value for current
			my $shiny_clamp_current=$clamp_current/10;

			# check current thresholds
			if (($clamp_current >= $response->{$diview_current_ucl.".".$opt_clamp} || $clamp_current <= $response->{$diview_current_lcl.".".$opt_clamp}) &&
			    ($response->{$diview_current_lcl.".".$opt_clamp} != 0 && $response->{$diview_current_ucl.".".$opt_clamp} != 0) ) {
				$output .= "current CRITICAL: $shiny_clamp_current, ";
				$error_level = "CRITICAL";
			} else {
				if (($clamp_current >= $response->{$diview_current_uwl.".".$opt_clamp} || $clamp_current <= $response->{$diview_current_lwl.".".$opt_clamp}) &&
				    ($response->{$diview_current_uwl.".".$opt_clamp} != 0 && $response->{$diview_current_lwl.".".$opt_clamp} != 0) ) {
					$output .= "current WARNING: $shiny_clamp_current, ";
					$error_level = "WARNING";
				} else {
					$output .= "current OK: $shiny_clamp_current, ";
				}
			}
			# check kwatts thresholds
			if (($clamp_kwatts >= $response->{$diview_kwatts_ucl.".".$opt_clamp} || $clamp_kwatts <= $response->{$diview_kwatts_lcl.".".$opt_clamp}) &&
			    ($response->{$diview_kwatts_lcl.".".$opt_clamp} != 0 && $response->{$diview_kwatts_ucl.".".$opt_clamp} != 0) ) {
				$output .= "kwatts CRITICAL: $clamp_kwatts, ";
				$error_level = "CRITICAL";
			} else {
				if (($clamp_kwatts >= $response->{$diview_kwatts_uwl.".".$opt_clamp} || $clamp_kwatts <= $response->{$diview_kwatts_lwl.".".$opt_clamp}) &&
				    ($response->{$diview_kwatts_uwl.".".$opt_clamp} != 0 && $response->{$diview_kwatts_lwl.".".$opt_clamp} != 0) ) {
					$output .= "kwatts WARNING: $clamp_kwatts, ";
					$error_level = "WARNING";
				} else {
					$output .= "kwatts OK: $clamp_kwatts, ";
				}
			}
			# check kva thresholds
			if (($clamp_kva >= $response->{$diview_kva_ucl.".".$opt_clamp} || $clamp_kva <= $response->{$diview_kva_lcl.".".$opt_clamp}) && 
			    ($response->{$diview_kva_lcl.".".$opt_clamp} != 0 && $response->{$diview_kva_ucl.".".$opt_clamp} != 0) ) {
				$output .= "kva CRITICAL: $clamp_kva, ";
				$error_level = "CRITICAL";
			} else {
				if (($clamp_kva >= $response->{$diview_kva_uwl.".".$opt_clamp} || $clamp_kva <= $response->{$diview_kva_lwl.".".$opt_clamp}) && 
				    ($response->{$diview_kva_uwl.".".$opt_clamp} != 0 && $response->{$diview_kva_lwl.".".$opt_clamp} != 0) ) {
					$output .= "kva WARNING: $clamp_kva, ";
					$error_level = "WARNING";
				} else {
					$output .= "kva OK: $clamp_kva, ";
				}
			}
			# check energy thresholds
			if ($clamp_energy >= $response->{$diview_energy_ucl.".".$opt_clamp}) {
				$output .= "energy CRITICAL: $clamp_energy, ";
				$error_level = "CRITICAL";
			} else {
				if ($clamp_energy >= $response->{$diview_energy_uwl.".".$opt_clamp}) {
					$output .= "energy WARNING: $clamp_energy";
					$error_level = "WARNING";
				} else {
					$output .= "energy OK: $clamp_energy";
				}
			}
			print $output."|voltage=${clamp_voltage}V;current=${clamp_current}V;kwatts=${clamp_kwatts}kWh;kva=${clamp_kva}kVA;energie=${clamp_kva}kWh\n";
			exit ( $states{$error_level} );
		} else {
			print "No input values found for port $opt_input\n";
			exit ( $states{UNKNOWN} );
		}
	}	
	
	
}

# -------------------------
# THE SUBS:
# -------------------------


# print_help($level, $msg);
# prints some message and the POD DOC
sub print_help {
	my ( $level, $msg ) = @_;
	$level = 0 unless ($level);
	if($level == -1) {
		print "$PROGNAME - Version: $VERSION\n";
		exit ( $states{UNKNOWN});
	}
	pod2usage(
		{
			-message => $msg,
			-verbose => $level
		}
	);

	exit( $states{UNKNOWN} );
}


1;

__END__

=head1 NAME

check_knuerr_rms.pl - Checks the knuerr_rms environmental devies for NAGIOS.

=head1 SYNOPSIS

check_knuerr_rms.pl -h

check_knuerr_rms.pl --man

check_knuerr_rms.pl -H <host> -I <input> | --clamp <port>  [-w <warning>] [-c <critical>]

=head1 DESCRIPTION

B<check_knuerr_rms.pl> recieves the data from the knuerr_rms devices. It can check thresholds of 
the connected probes(temperature,humidity,analogue,contact) or the state of connected contacts.

=head1 OPTIONS

=over 8

=item B<-h>

Display this helpmessage.

=item B<-H>

The hostname or ipaddress of the knuerr_rms device.

=item B<-C>

The snmp community of the knuerr_rms device.

=item B<-I>

The input where the probe is connected to.

=item B<--clamp>

The port where the clamp is connected to.

=item B<-w>

The warning threshold. 

=item B<-c>

The critical threshold. 

=item B<--man>

Displays the complete perldoc manpage.

=back

=cut

=head1 THRESHOLD FORMATS

B<1.> start <= end

Thresholds have to be specified from the lower level end on e.g. -w 20 is meaning that a
warning error is occuring when the collected value is over 20.

=head1 VERSION

$Id: 69a2b16d259d09f34992bfaedf00f611eefa0853 $

=head1 AUTHOR

NETWAYS GmbH, 2009, http://www.netways.de.

Written by Michael Streb <michael.streb@netways.de>.

Please report bugs through the contact of Nagios Exchange, http://www.nagiosexchange.org. 

