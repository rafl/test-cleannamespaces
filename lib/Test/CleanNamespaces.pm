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

=head1 SYNOPSIS

    use strict;
    use warnings;
    use Test::CleanNamespaces;

    all_namespaces_clean;

=head1 DESCRIPTION

This module lets you check your module's namespaces for imported functions you
might have forgotten to remove with L<namespace::autoclean> or
L<namespace::clean> and are therefor available to be called as methods, which
usually isn't want you want.

=head1 FUNCTIONS

All functions are exported by default.

=head2 namespaces_clean

    namespaces_clean('YourModule', 'AnotherModule');

Tests every specified namespace for uncleaned imports. If the module couldn't
be loaded it will be skipped.

=head2 all_namespaces_clean

    all_namespaces_clean;

Runs C<namespaces_clean> for all modules in your distribution.

=head1 METHODS

The exported functions are constructed using the the following methods. This is
what you want to override if you're subclassing this module..

=head2 build_namespaces_clean

    my $coderef = Test::CleanNamespaces->build_namespaces_clean;

Returns a coderef that will be exported as C<namespaces_clean>.

=cut

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
            my %methods = map { ($_ => 1) } $meta->get_method_list;
            my @symbols = keys %{ $meta->get_all_package_symbols('CODE') || {} };
            my @imports = grep { !$methods{$_} } @symbols;

            $class->builder->ok(!@imports, "${ns} contains no imported functions");
            $class->builder->diag(
                $class->builder->explain('remaining imports: ' => \@imports)
            ) if @imports;
        }
    };
}

=head2 build_all_namespaces_clean

    my $coderef = Test::CleanNamespaces->build_namespaces_clean;

Returns a coderef that will be exported as C<all_namespaces_clean>. It will use
the C<find_modules> method to get the list of modules to check.

=cut

sub build_all_namespaces_clean {
    my ($class, $name) = @_;
    my $namespaces_clean = $class->build_namespaces_clean($name);
    return sub {
        my @modules = $class->find_modules(@_);
        $class->builder->plan(tests => scalar @modules);
        $namespaces_clean->(@modules);
    };
}

=head2 find_modules

    my @modules = Test::CleanNamespaces->find_modules;

Returns a list of modules in the current distribution. It'll search in
C<blib/>, if it exists. C<lib/> will be searched otherwise.

=cut

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

=head2 builder

    my $builder = Test::CleanNamespaces->builder;

Returns the C<Test::Builder> used by the test functions.

=cut

{
    my $Test = Test::Builder->new;
    sub builder { $Test }
}

1;
