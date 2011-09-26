package Mojolicious::Plugin::CSRFProtect;
use strict;
use warnings;
use Carp qw/croak/;

use Mojo::Base 'Mojolicious::Plugin';
use Mojo::Util qw/md5_sum/;
use Mojo::ByteStream qw/b/;

our $VERSION = '0.02';

sub register {
    my ( $self, $app ) = @_;
    my $original_form_for = $app->renderer->helpers->{form_for};
    croak qq{Cannot find helper "form_for". Please, load plugin "TagHelpers" before}
        unless $original_form_for;

    # Replace "form_for" helper
    $app->helper(
        form_for => sub {
            my $c = shift;
            if ( defined $_[-1] && ref( $_[-1] ) eq 'CODE' ) {
                my $cb = $_[-1];
                $_[-1] = sub {
                    $app->hidden_field( 'csrftoken' => $self->_csrftoken($c) ) . $cb->();
                };
            }
            return $app->$original_form_for(@_);
        } );

    # Add "csrftoken" helper
    $app->helper( csrftoken => sub { $self->_csrftoken( $_[0] ) } );

    # Add "is_valid_csrftoken" helper
    $app->helper( is_valid_csrftoken => sub { $self->_is_valid_csrftoken( $_[0] ) } );

    # Add "jquery_ajax_csrf_protection" helper
    $app->helper(
        jquery_ajax_csrf_protection => sub {
            my $js = '<meta name="csrftoken" content="' . $self->_csrftoken( $_[0] ) . '"/>';
            $js .= q!<script type="text/javascript">!;
            $js .= q! $(document).ajaxSend(function(e, xhr, options) { !;
            $js .= q!    var token = $("meta[name='csrftoken']").attr("content");!;
            $js .= q! xhr.setRequestHeader("X-CSRF-Token", token);!;
            $js .= q! });</script>!;

            b($js);
        } );

    # input check
    $app->hook(
        after_static_dispatch => sub {
            my ($c) = @_;
            my $request_token = $c->req->param('csrftoken');
            my $is_ajax = ( $c->req->headers->header('X-Requested-With') || '' ) eq 'XMLHttpRequest';
            if ( ( $is_ajax || $c->req->method ne 'GET' ) && !$self->_is_valid_csrftoken($c) ) {
                $c->render(
                    status => 403,
                    text   => "Wrong CSRF protection token!",
                );
                return;
            }

            return 1;
        } );

}

sub _is_valid_csrftoken {
    my ( $self, $c ) = @_;
    my $valid_token = $c->session('csrftoken');
    my $form_token = $c->req->headers->header('X-CSRF-Token') || $c->req->param('csrftoken');

    unless ( $valid_token && $form_token && $form_token eq $valid_token ) {
        return 0;
    }

    return 1;
}

sub _csrftoken {
    my ( $self, $c ) = @_;
    return $c->session('csrftoken') if $c->session('csrftoken');

    my $token = md5_sum( md5_sum( time() . {} . rand() . $$ ) );
    $c->session( 'csrftoken' => $token );
    return $token;
}

1;

__END__

=head1 NAME

Mojolicious::Plugin::CSRFProtect - Mojolicious Plugin

=head1 SYNOPSIS

  # Mojolicious
  $self->plugin('CSRFProtect');

  # Mojolicious::Lite
  plugin 'CSRFProtect';
  
  # Use C<form_for> helper and all your html forms will have CSRF protection token 

    <%= form_for login => (method => 'post') => begin %>
           <%= text_field 'first_name' %>
           <%= submit_button %>
    <% end %>
    
  # Place jquery_ajax_csrf_protection helper to your layout template 
  # and all AJAX requests will have CSRF protection token (requires JQuery)
   
    <%= jquery_ajax_csrf_protection %>


=head1 DESCRIPTION

L<Mojolicious::Plugin::CSRFProtect> is a L<Mojolicious> plugin fully protects you from CSRF attacks.

It does next thing:

1. Adds hidden input (csrftoken) with CSRF protection token to every form 
(works only if you use C<form_for> helper from Mojolicious::Plugin::TagHelpers) 

2. Adds header "X-CSRF-Token" with CSRF token to every AJAX request (works with JQuery only)   

3. Rejects all non GET request without correct CSRF protection token.
 

If you want protect your GET requests then you can do it manually

In template: <a href="/delete_user/123/?csrftoken=<%= csrftoken %>">

In controller: $self->is_valid_csrftoken( $self->param("csrftoken") ) 

=head1 HELPERS

=head2 C<form_for>

    This helper overrides the C<form_for> helper from Mojolicious::Plugin::TagHelpers 
    
    and adds hidden input with CSRF protection token.

=head2 C<jquery_ajax_csrf_protection>

    This helper adds CSRF protection headers to all JQuery AJAX requests.
    
    You should add <%= jquery_ajax_csrf_protection %> in head of your HTML page. 

=head2 C<csrftoken>

    returns  CSRF Protection token. 
    
    In templates <%= csrftoken %>
    
    In controller $self->csrftoken;
    
=head2 C<is_valid_csrftoken>

    With this helper you can check $csrftoken manually. 
     
    $self->is_valid_csrftoken($csrftoken) will return 1 or 0

=head1 SEE ALSO

=over 4

=item L<Mojolicious::Plugin::CSRFDefender>

=item L<Mojolicious>

=item L<Mojolicious::Guides> 

=item L<http://mojolicio.us>

=back

=cut
