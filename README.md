check_knuerr_rms
================

`check_knuerr_rms.pl` recieves the data from the knuerr_rms devices. It can check thresholds of 
the connected probes(temperature,humidity,analogue,contact) or the state of connected contacts.

http://www.netways.de/en/de/produkte/icinga_and_nagios_plugins/knuerr/


### Requirements

* Perl libraries: `Net::SNMP`


### Usage

    check_knuerr_rms.pl -h

    check_knuerr_rms.pl --man

    check_knuerr_rms.pl -H <host> -I <input> | --clamp <port> [-w <warning>]
    [-c <critical>]

Options:

    -h      Display this helpmessage
    -H      The hostname or ipaddress of the knuerr_rms device.
    -C      The snmp community of the knuerr_rms device.
    -I      The input where the probe is connected to.
    --clamp The port where the clamp is connected to.
    -w      The warning threshold.
    -c      The critical threshold.
    --man   Displays the complete perldoc manpage.
