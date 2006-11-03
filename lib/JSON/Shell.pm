#!/usr/bin/perl -w

use strict;

package JSON::Shell;

use Shell::Base;
use LWP::UserAgent;
use HTTP::Cookies;
use Data::Dumper;
use JSON;

use base qw( Shell::Base );

our $VERSION = '1.0';


sub init {
    my ($me, $args) = @_;

    $me->{cookies} = HTTP::Cookies->new(
        file => '.jsonshell_cookies',
        autosave => 1,
    );
    $me->{ua} = LWP::UserAgent->new(
        agent      => "jsonshell/$VERSION",
        cookie_jar => $me->{cookies},
        env_proxy  => 1,
    );

    if(my $endpoint = $me->config('endpoint')) {
        eval { $me->_set_endpoint($endpoint); };
        $me->print('WARNING: endpoint from rcfile is not a valid URI.') if $@;
    }

    1;
}


sub intro {
    "JSON::Shell $VERSION\n";
}

sub prompt {
    my ($me) = @_;
    my $prompt = $me->{prompt} || '';
    $prompt . '$ ';
}

sub outro { '' }


sub default {
    my ($me, $cmd, @args) = @_;
    "I don't know what you mean by '$cmd'.";
}

sub _set_endpoint {
    my ($me, $endpoint) = @_;
    my $uri = URI->new($endpoint);
    die "Endpoint does not seem to be a URI.\n" unless $uri;
    $me->{endpoint} = $uri->as_string;
    $me->{prompt} = $uri->host . $uri->path;
    1;
}

sub help_endpoint {
    return <<'HELP';

endpoint <URL>
endpoint

Set or view the current endpoint. The endpoint is the URL to which posts are
made with the 'post' command.
HELP
}

sub do_endpoint {
    my ($me, $endpoint) = @_;
    if ($endpoint) {
        eval { $me->_set_endpoint($endpoint); };
        return $@ || "Endpoint set.";
    }

    if ($endpoint = $me->{endpoint}) {
        return "Current endpoint is: $endpoint";
    }

    return "Endpoint is not set."
}

sub help_parse {
    return <<'HELP';

parse <JSON>

Parses <JSON> as a JSON string and shows the resulting Perl data structure.
HELP
}

sub do_parse {
    my ($me, $json) = @_;

    my $obj;
    eval { $obj = JSON->new->jsonToObj($json); };
    return "JSON error: $@" if $@;

    return Dumper($obj);
}

sub help_post {
    return <<'HELP';

post <JSON>
post <method> [<id>] <JSON>

Posts the given JSON string to the current endpoint. The resulting Perl data
structures of both the request and response are shown.

If <method> is given, posts the given JSON as a parameter in a JSON-RPC request
of the given method and id. If no id is given, one is generated automatically.
HELP
}

sub do_post {
    my ($me, @stuff) = @_;
    return "No endpoint defined; see 'endpoint'" unless $me->{endpoint};

    my $post_json;
    if(1 == scalar @stuff) {
        $post_json = $stuff[0];
    } elsif(2 == scalar @stuff || 3 == scalar @stuff) {
        my $method = $stuff[0];
        my $id     = (2 == scalar @stuff) ? int(rand() * 1_000_000) : $stuff[1];
        my $params = $stuff[-1];
        $post_json = qq({ "method": "$method", "id": $id, "params": [ $params ] });
    } else {
        return "I don't know what you want to post with that number number of parameters.";
    }

    ## Make sure it parses.
    eval {
        my $json_req = JSON->new->jsonToObj($post_json);
        $me->print("REQUEST: " . Dumper($json_req) . "\n");
    };
    if(my $err = $@) {
        $err =~ s([\r\n].+)(...)s;
        return "JSON error in request: $err";
    }

    my $req = HTTP::Request->new('POST', $me->{endpoint});
    $req->content($post_json);
    $req->header('Content-Type', 'text/javascript+json');
    my $resp = $me->{ua}->request($req);

    $me->{last_response} = $resp->content;
    return "HTTP error: " . $resp->status_line unless $resp->is_success;

    my $resp_json;
    eval { $resp_json = JSON->new->jsonToObj($resp->content); };
    if(my $err = $@) {
        $err =~ s([\r\n].*)(...)s;
        return "JSON error in response: $err";
    }

    return "RESPONSE: " . Dumper($resp_json);
}

sub help_response {
    return <<'HELP';

response

Displays the unparsed HTTP response from the most recently performed request,
through your preferred pager. Use this command to view the of HTTP errors
received through the 'post' command.
HELP
}

sub do_response {
    my ($me) = @_;
    my $pager = $me->pager;

    open my $P, "|$pager" or $me->print($me->{last_response}), return;
    CORE::print $P $me->{last_response};
    close $P;

    '';
}

1;

__END__

=head1 NAME

JSON::Shell - an interactive shell for performing JSON and JSON-RPC requests


=head1 SYNOPSIS

    $ bin/jsonshell

    JSON::Shell 1.0
    www.example.com/json-rpc-demo$ post '{ "id": 1, "method": "echoObject", "params": { "o": [ "YAY JSON~" ] } }'
    REQUEST: $VAR1 = {
              'params' => {
                            'o' => [
                                     'YAY JSON~'
                                   ]
                          },
              'method' => 'echoObject',
              'id' => '1'
            };

    RESPONSE: $VAR1 = {
              'id' => '1',
              'result' => [
                            'YAY JSON~'
                          ]
            };

    www.example.com/json-rpc-demo$ 

 
=head1 DESCRIPTION

JSON::Shell provides an interactive debugger and workbench for JSON based web
services.


=head1 USAGE

Typically you would use JSON::Shell through the provided C<bin/jsonshell>
script. See L<Shell::Base> for the options available to use JSON::Shell
programmatically.


=head1 COMMANDS

=head2 endpoint E<lt>URLE<gt>

Defines the JSON endpoint to which posts will be issued.

=head2 parse E<lt>JSON codeE<gt>

Evaluates the given JSON code into a data structure, displaying it if
successful. Use this command to check if your JSON syntax is correct.

=head2 post E<lt>JSON codeE<gt>

Evaluates the given JSON code to check its validity, then posts it to the
current endpoint, displaying the JSON response.

=head2 post E<lt>JSON-RPC methodE<gt> [E<lt>JSON-RPC request IDE<gt>] E<lt>JSON codeE<gt>

Evaluates the given JSON code to check its validity, then posts it to the
current endpoint as a JSON-RPC request of the given method. If a JSON-RPC
request ID is not given, one is generated randomly and used in the request.

=head2 response

Displays the content of the last HTTP response in your configured pager. Use
this to diagnose malformed responses, as some environments may not return
especially egregious errors in JSON format.


=head1 DIAGNOSTICS

=over

=item C<< I don't know what you mean by '%s'. >>

You issued the given command in the shell, but that command is not defined by
JSON::Shell. Perhaps you misspelled one of the defined commands.

=item C<< JSON error: %s >>

While parsing a JSON string using the C<parse> command, JSON::Shell encountered
the given error. Perhaps the string you asked to parse was not correctly formed
JSON.

=item C<< I don't know what you want to post with that number number of parameters. >>

You specified an undefined number of parameters to C<post>. Only posts with one
parameter (a JSON string), two parameters (a JSON-RPC method and params hash),
and three parameters (a JSON-RPC method, invocation ID, and params hash) are
supported. Perhaps you didn't enclose a command parameter containing spaces in
quotes.

=item C<< No endpoint defined; see 'endpoint' >>

You attempted to issue a post or login without defining an endpoint first. An
endpoint URL is required to send JSON requests. Perhaps your endpoint URL was
mistyped, or your C<.jsonshellrc> file is misplaced or malformed.

=item C<< JSON error in request: %s >>

The request you asked to post was not valid JSON, for the given reason. Perhaps
you mistyped it, or didn't enclose your request in quotes.

=item C<< HTTP error: %s >>

The HTTP request just issued failed, with the given status line. Perhaps the
endpoint URL is incorrect, or there is an actual error with the server. You
might also use the C<response> command to view the body of the response.

=item C<< JSON error in response: %s >>

The attempt to parse your request's response as JSON failed, for the given
reason. Perhaps your endpoint is incorrectly pointing at an XML or HTML
resource, or your request produced a server error in XML or HTML, or the server
produced malformed JSON. Use the C<response> command to view the unparsed body
of the response.

=back


=head1 CONFIGURATION AND ENVIRONMENT

JSON::Shell can be configured with a C<.jsonshellrc> file in the directory from
which C<jsonshell> is invoked. Options available in the C<.jsonshellrc> file are:

=over

=item C<< endpoint = <URL> >>

This option defines the endpoint to which JSON requests are posted.

=back

JSON::Shell also performs web requests using the file C<.jsonshell_cookies> in
the directory from which C<jsonshell> is invoked for an LWP cookie jar. If the
service you're using requires you to authenticate with cookies, you can place
those cookies in the C<.jsonshell_cookies> file.  See L<HTTP::Cookies> for
information on LWP cookie jar files.


=head1 DEPENDENCIES

=over

=item Shell::Base

=item JSON

=back


=head1 INCOMPATIBILITIES

None reported.


=head1 BUGS AND LIMITATIONS

No bugs have been reported.

Please report any bugs or feature requests to
C<bug-json-shell@rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org>.


=head1 SEE ALSO

=over

=item L<Shell::Base>

=item L<JSON>

=item JSON-RPC C<< <http://json-rpc.org/> >>

=item L<HTTP::Cookies>

=back


=head1 AUTHOR

Mark Paschal  C<< <mark@sixapart.com> >>


=head1 LICENCE AND COPYRIGHT

Copyright 2005-2006 Six Apart, Ltd. All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.


=head1 DISCLAIMER OF WARRANTY

BECAUSE THIS SOFTWARE IS LICENSED FREE OF CHARGE, THERE IS NO WARRANTY
FOR THE SOFTWARE, TO THE EXTENT PERMITTED BY APPLICABLE LAW. EXCEPT WHEN
OTHERWISE STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER PARTIES
PROVIDE THE SOFTWARE "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER
EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE
ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE SOFTWARE IS WITH
YOU. SHOULD THE SOFTWARE PROVE DEFECTIVE, YOU ASSUME THE COST OF ALL
NECESSARY SERVICING, REPAIR, OR CORRECTION.

IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING
WILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MAY MODIFY AND/OR
REDISTRIBUTE THE SOFTWARE AS PERMITTED BY THE ABOVE LICENCE, BE
LIABLE TO YOU FOR DAMAGES, INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL,
OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE OR INABILITY TO USE
THE SOFTWARE (INCLUDING BUT NOT LIMITED TO LOSS OF DATA OR DATA BEING
RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR THIRD PARTIES OR A
FAILURE OF THE SOFTWARE TO OPERATE WITH ANY OTHER SOFTWARE), EVEN IF
SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE POSSIBILITY OF
SUCH DAMAGES.

=cut

