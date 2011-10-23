#!/usr/bin/env perl
use Mojo::Base -strict;
use Mojolicious::Lite;
use Test::Mojo;
use Test::More;
use lib 'lib';
plugin 'CSRFProtect';

my $t = Test::Mojo->new;

my $csrftoken;

get '/get_without_token' => sub {
    my $self = shift;
    $csrftoken = $self->csrftoken;
    $self->render_text('get_without_token');
};

get '/protected_document';

get '/get_with_token/:csrftoken' => sub {
    my $self = shift;

    if ( $self->is_valid_csrftoken() ) {
        $self->render_text( 'valid csrftokentoken', status => 200 );
    } else {
        $self->render_text( 'Forbidden!', status => 403 );
    }

};

post '/post_with_token' => sub {
    my $self = shift;
    $self->render_text('valid csrftokentoken');
};


# GET /get_without_token. First request will generate new token
$t->get_ok('/get_without_token')->status_is(200)->content_is('get_without_token');
$t->get_ok('/get_without_token')->status_is(200)->content_is('get_without_token');

# GET /get_with_token
$t->get_ok("/get_with_token/$csrftoken")->status_is(200)->content_is('valid csrftokentoken');
$t->get_ok("/get_with_token/wrongtoken")->status_is(403)->content_is('Forbidden!');

# POST /post_with_token
$t->post_form_ok( "/post_with_token", { csrftoken => $csrftoken } )->status_is(200)
    ->content_is('valid csrftokentoken');
$t->post_form_ok( "/post_with_token", { csrftoken => 'wrongtoken' } )->status_is(403)
    ->content_is('Forbidden!');

# Emulate AJAX All
# AJAX request should be checked (including GET)
$t->ua->on(
    start => sub {
        my ( $ua, $tx ) = @_;
        $tx->req->headers->header( 'X-Requested-With', 'XMLHttpRequest' );
    } );

$t->get_ok('/get_without_token')->status_is(403)->content_is('Forbidden!');
$t->post_form_ok( "/post_with_token", { csrftoken => $csrftoken } )->status_is(200)
    ->content_is('valid csrftokentoken');
$t->post_form_ok( "/post_with_token", { csrftoken => 'wrongtoken' } )->status_is(403)
    ->content_is('Forbidden!');

# Add header with csrftoken
$t->ua->on(
    start => sub {
        my ( $ua, $tx ) = @_;
        $tx->req->headers->header( 'X-CSRF-Token', $csrftoken );
    } );

# All request should pass
$t->get_ok('/get_without_token')->status_is(200)->content_is('get_without_token');
$t->get_ok("/get_with_token/notoken")->status_is(200)->content_is('valid csrftokentoken');
$t->post_ok("/post_with_token")->status_is(200)->content_is('valid csrftokentoken');

# Check helpers
my $javascript = qq~<meta name="csrftoken" content="$csrftoken"/><script type="text/javascript"> \$(document).ajaxSend(function(e, xhr, options) {     var token = \$("meta[name='csrftoken']").attr("content"); xhr.setRequestHeader("X-CSRF-Token", token); });</script>\n~;
$t->get_ok('/protected_document')->status_is(200)->content_is("$javascript");

done_testing;

__DATA__;

@@ protected_document.html.ep
<%= jquery_ajax_csrf_protection %>