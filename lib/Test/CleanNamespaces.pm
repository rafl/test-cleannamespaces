use strict;
use warnings;

package Test::CleanNamespaces;
# ABSTRACT: Check for uncleaned imports

use Class::MOP;
use Sub::Name 'subname';
use Test::Builder;
use File::Find::Rule;
use File::Find::Rule::Perl;
use File::Spec::Functions 'splitdir';
use namespace::autoclean;

use Sub::Exporter -setup => {
    exports => [
        namespaces_clean     => \&build_namespaces_clean,
        all_namespaces_clean => \&build_all_namespaces_clean,
    ],
    groups => {
        default => [qw/namespaces_clean all_namespaces_clean/],
    },
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
    my ($class, $name) = @_;
    return sub {
        my (@namespaces) = @_;
        local $@;

        for my $ns (@namespaces) {
            unless (eval { Class::MOP::load_class($ns); 1 }) {
                $class->builder->skip("failed to load ${ns}: $@");
                next;
            }

            my $meta = Class::MOP::class_of($ns) || Class::MOP::Class->initialize($ns);
            my %methods = map { ($_ => 1) } keys %{ $meta->get_method_map || {} };
            my @symbols = keys %{ $meta->get_all_package_symbols('CODE') || {} };
            my @imports = grep { !$methods{$_} } @symbols;

            $class->builder->ok(!@imports, "${ns} contains no imported functions");
            $class->builder->diag(
                $class->builder->explain('remaining imports: ' => \@imports)
            ) if @imports;
        }
    };
}

sub build_all_namespaces_clean {
    my ($class, $name) = @_;
    my $namespaces_clean = $class->build_namespaces_clean($name);
    return sub {
        my @modules = $class->find_modules(@_);
        $class->builder->plan(tests => scalar @modules);
        $namespaces_clean->(@modules);
    };
}

sub find_modules {
    my ($class) = @_;
    my @modules = map {
        /^blib/
            ? s/^blib.(?:lib|arch).//
            : s/^lib.//;
        s/\.pm$//;
        join '::' => splitdir($_);
    } File::Find::Rule->perl_module->in(-e 'blib' ? 'blib' : 'lib');
    return @modules;
}

1;
