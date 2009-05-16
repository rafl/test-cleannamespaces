use strict;
use warnings;

package Test::CleanNamespaces;

use Class::MOP;
use Sub::Name 'subname';
use namespace::autoclean;

use Sub::Exporter -setup => {
    exports => [
        namespaces_clean => \&build_namespaces_clean,
    ],
    groups => { default => ['namespaces_clean'] },
};

BEGIN {
    # temporary hack to make import into a real named method until
    # Sub::Exporter does it for us.
    *import = subname __PACKAGE__ . '::import', \&import;
}

{
    my $Test = Test::Builder->new;
    sub builder { $Test }
}

sub build_namespaces_clean {
    my ($class, $name, $arg) = @_;
    return sub {
        my (@namespaces) = @_;
        local $@;

        for my $ns (@namespaces) {
            unless (eval { Class::MOP::load_class($ns); 1 }) {
                $class->builder->ok(0, "failed to load ${ns}: $@");
                next;
            }

            my $meta = Class::MOP::class_of($ns) || Class::MOP::Class->initialize($ns);
            my %methods = map { ($_ => 1) } keys %{$meta->get_method_map};
            my @symbols = keys %{ $meta->get_all_package_symbols('CODE') };
            my @imports = grep { !$methods{$_} } @symbols;

            $class->builder->ok(!@imports, "${ns} contains no imported functions");
            $class->builder->diag(
                $class->builder->explain('remaining imports: ' => \@imports)
            ) if @imports;
        }
    };
}

1;
