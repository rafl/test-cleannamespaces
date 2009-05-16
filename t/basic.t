use strict;
use warnings;
use Test::Tester tests => 21;
use Test::More;

use Test::CleanNamespaces;

use FindBin;
use lib "$FindBin::Bin/lib";

{
    check_test(sub { namespaces_clean('Test::CleanNamespaces') }, {
        ok => 1,
        name => 'Test::CleanNamespaces contains no imported functions',
    }, 'namespaces_clean success');
}

{
    my (undef, $result) = check_test(sub { namespaces_clean('DoesNotCompile') }, {
        ok => 1,
        type => 'skip',
    }, 'namespace_clean compilation fail');

    like($result->{reason}, qr/failed to load/, 'useful diagnostics on compilation fail');
}

{
    my (undef, $result) = check_test(sub { namespaces_clean('Dirty') }, {
        ok => 0,
        name => 'Dirty contains no imported functions',
    }, 'unclean namespace');

    like($result->{diag}, qr/remaining imports/, 'diagnostic mentions "remaining imports"');
    like($result->{diag}, qr/stuff/, 'diagnostic lists the remaining imports');
}
