#!/usr/bin/perl

use Modern::Perl;

use CGI;
use Getopt::Long;

use C4::Context;
use lib C4::Context->config("pluginsdir");

use Koha::Plugin::Com::ByWaterSolutions::IpWhiteList;

my $cgi = new CGI;

my $type;
my $format;

GetOptions (
    "type=s"   => \$type,
    "format=s" => \$format,
);

$type ||= $cgi->param('type');
$format ||= $cgi->param('format');

my $plugin = Koha::Plugin::Com::ByWaterSolutions::IpWhiteList->new({ cgi => $cgi });
my $output = $plugin->output_format( { type => $type, format => $format } );

print $output;
