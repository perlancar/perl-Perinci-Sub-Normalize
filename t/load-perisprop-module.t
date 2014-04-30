#!perl

use 5.010;
use strict;
use warnings;

use Perinci::Sub::Normalize qw(normalize_function_metadata);
use Test::Exception;
use Test::More 0.98;

plan skip_all => "Release testing only"
    unless $ENV{RELEASE_TESTING};

is_deeply(normalize_function_metadata({v=>1.1, retry=>2}),
          {v=>1.1, retry=>2});
is_deeply(normalize_function_metadata({v=>1.1, result=>{table=>{}}}),
          {v=>1.1, result=>{table=>{}}});
dies_ok { normalize_function_metadata({v=>1.1, foo=>1}) }
        "doesn't allow unknown properties";
dies_ok { normalize_function_metadata({v=>1.1, result=>{foo=>1}}) }
        "doesn't allow unknown result properties";

DONE_TESTING:
done_testing();
