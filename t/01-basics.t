#!perl

use 5.010;
use strict;
use warnings;

use Perinci::Sub::Normalize qw(normalize_function_metadata);
use Test::Exception;
use Test::More 0.98;

subtest defaults => sub {
    dies_ok { normalize_function_metadata({}) }
        "doesn't accept v1.0";
    dies_ok { normalize_function_metadata({v=>1.1, foo=>1}) }
        "doesn't allow unknown properties";
    is_deeply(normalize_function_metadata({v=>1.1, foo=>1}, {allow_unknown_properties=>1}),
              {v=>1.1, foo=>1},
              "unknown properties allowed when using allow_unknown_properties=1");

    is_deeply(normalize_function_metadata({v=>1.1}),
              {v=>1.1});
    is_deeply(normalize_function_metadata({v=>1.1, args=>{}}),
              {v=>1.1, args=>{}});
    is_deeply(normalize_function_metadata({v=>1.1, args=>{a=>{schema=>"int"}, b=>{schema=>["str*"]} }, result=>{schema=>"array"}}),
              {v=>1.1, args=>{a=>{schema=>["int",{},{}]}, b=>{schema=>["str",{req=>1},{}]} }, result=>{schema=>["array",{},{}]}},
              'sah schemas normalized');
    is_deeply(normalize_function_metadata({v=>1.1, args=>{a=>{schema=>"int"}, b=>{schema=>["str*"]} }, result=>{schema=>"array"}}, {normalize_sah_schemas=>0}),
              {v=>1.1, args=>{a=>{schema=>"int"}, b=>{schema=>["str*"]}}, result=>{schema=>"array"}},
              'sah schemas not normalized when using normalize_sah_schemas=>0');
};

DONE_TESTING:
done_testing();
