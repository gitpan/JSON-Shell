#!/usr/bin/perl -w

use strict;
use warnings;

use Test::More;

eval "use Test::Pod 1.00";
plan skip_all => 'Test::Pod 1.00 required for testing POD'
     if $@;

use Test::Pod::Coverage tests => 1;
pod_coverage_ok('JSON::Shell', {
    coverage_class => 'Pod::Coverage::CountParents',
    also_private   => [ qr{ \A (?:do|help)_ }xms ],
});

