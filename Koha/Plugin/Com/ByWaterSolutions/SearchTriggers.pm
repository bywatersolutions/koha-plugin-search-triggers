package Koha::Plugin::Com::ByWaterSolutions::SearchTriggers;

## It's good practive to use Modern::Perl
use Modern::Perl;

## Required for all plugins
use base qw(Koha::Plugins::Base);

## We will also need to include any Koha libraries we want to access
use C4::Context;
use C4::Members;
use C4::Auth;
use Koha::DateUtils;
use Koha::Libraries;
use Koha::Patron::Categories;
use Koha::Account;
use Koha::Account::Lines;
use MARC::Record;
use Cwd qw(abs_path);
use URI::Escape qw(uri_unescape);
use LWP::UserAgent;
use JSON qw( to_json from_json );

## Here we set our plugin version
our $VERSION = "{VERSION}";

## Here is our metadata, some keys are required, some are optional
our $metadata = {
    name            => 'Search Triggers',
    author          => 'Kyle M Hall',
    date_authored   => '2009-01-27',
    date_updated    => "1900-01-01",
    minimum_version => '18.05.00.000',
    maximum_version => undef,
    version         => $VERSION,
    description     => 'This plugin allows a library to define search triggers that will cause a popup info box to display with info definted by the given parameters'
};

## This is the minimum code required for a plugin's 'new' method
## More can be added, but none should be removed
sub new {
    my ( $class, $args ) = @_;

    ## We need to add our metadata here so our base class can access it
    $args->{'metadata'} = $metadata;
    $args->{'metadata'}->{'class'} = $class;

    ## Here, we call the 'new' method for our base class
    ## This runs some additional magic and checking
    ## and returns our actual $self
    my $self = $class->SUPER::new($args);

    return $self;
}

sub report {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};

    my $interface = $cgi->param('interface') eq 'staff' ? 'staff' : 'opac';
    my $q = $cgi->param('q');

    my $config = from_json( $self->retrieve_data("search_triggers_$interface") );

    my @matches;
    foreach my $c ( @$config ) {
        my $keywords = ($c->{keywords});
        my $style = $c->{style};

        my $match = 0;
        if ( $style eq 'any' ) {
            foreach my $k (@$keywords) {
                if ( index( $q, $k ) != -1 ) {
                    $match = 1;
                    last;
                }
            }
        }
        elsif ( $style eq 'all' ) {
            my $matches_count = 0;
            foreach my $k (@$keywords) {
                if ( index( $q, $k ) != -1 ) {
                    $matches_count++;
                }
            }
            $match = 1 if $matches_count == scalar @$keywords;
        }

        if ( $match ) {
            push( @matches, $c );
        }
    }

    print $cgi->header(
        {
            -type     => 'application/json',
            -charset  => 'UTF-8',
            -encoding => "UTF-8"
        }
    );
    print to_json( \@matches );
}

## If your tool is complicated enough to needs it's own setting/configuration
## you will want to add a 'configure' method to your plugin like so.
## Here I am throwing all the logic into the 'configure' method, but it could
## be split up like the 'report' method is.
sub configure {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};

    unless ( $cgi->param('save') ) {
        my $template = $self->get_template({ file => 'configure.tt' });

        ## Grab the values we already have for our settings, if any exist
        $template->param(
            search_triggers_opac => $self->retrieve_data('search_triggers_opac'),
            search_triggers_staff => $self->retrieve_data('search_triggers_staff'),
        );

        $self->output_html( $template->output() );
    }
    else {
        $self->store_data(
            {
                search_triggers_opac => $cgi->param('search_triggers_opac'),
                search_triggers_staff => $cgi->param('search_triggers_staff'),
            }
        );
        $self->go_home();
    }
}

sub output_format {
    my ( $self, $params ) = @_;

    my $type = $params->{type};
    my $format = $params->{format} || 'default';
    
    die "Invalid type: $type! Valid types are 'opac' and 'staff'"
    	unless ( $type eq 'staff' || $type eq 'opac' );

    die "Invalid format: $format!"
    	unless ( $format eq 'default' );

    my $ip_list = $self->retrieve_data("search_triggers_$type");

    return $ip_list;
}

1;
