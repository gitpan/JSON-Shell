#!/usr/bin/perl -w

use strict;
use warnings;

use Test::More;

eval { require Test::Kwalitee; Test::Kwalitee->import(); };

plan skip_all => 'Test::Kwalitee is required to test module kwalitee'
    if $@;

