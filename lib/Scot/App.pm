package Scot::App;

use lib '../../lib';
use v5.18;
use strict;
use warnings;
use Try::Tiny;
use Scot::Util::LoggerFactory;
use Data::Dumper;
use DateTime;
use namespace::autoclean;

use Moose;

has env => (
    is          => 'ro',
    isa         => 'Scot::Env',
    required    => 1,
    lazy        => 1,
    builder     => '_get_env',
);

sub _get_env {
    my $self    = shift;
    my $file    = $self->config_file;
    return Scot::Env->new({
        config_file => $file,
    });
}

has log => (
    is          => 'ro',
    isa         => 'Log::Log4perl::Logger',
    required    => 1,
    lazy        => 1,
    builder     => '_build_log',
    predicate   => 'has_log',
);

sub _build_log {
    my $self    = shift;
    my $env     = $self->env;
    return $env->log;
}

sub get_config_value {
    my $self    = shift;
    my $attr    = shift;
    my $default = shift;
    my $envname = shift;
    my $env     = $self->env;

    if ( defined $envname ) {
        if ( defined $ENV{$envname} ) {
            return $ENV{$envname};
        }
    }
    if ( defined $env->$attr ) {
        return $env->$attr;
    }
    return $default;
}

has base_url    => (
    is              => 'ro',
    isa             => 'Str',
    required        => 1,
    default         => '/scot/api/v2',
);

sub put_stat {
    my $self    = shift;
    my $metric  = shift;
    my $value   = shift;
    my $now     = DateTime->now;

    try {
        if ( $self->get_method eq "scot_api" ) {
            my $response    = $self->scot->post({
                type    => "stat",
                data    => {
                    action  => 'incr',
                    year    => $now->year,
                    month   => $now->month,
                    day     => $now->day,
                    hour    => $now->hour,
                    dow     => $now->dow,
                    quarter => $now->quarter,
                    metric  => $metric,
                    value   => $value,
                }
            });
        }
        else {
            my $mongo   = $self->env->mongo;
            my $col     = $mongo->collection('Stat');
            $col->increment($now, $metric, $value);
        }
    }
    catch {
        $self->log->warn("Attempt to put stat $metric $value failed!");
    };
}


1;
