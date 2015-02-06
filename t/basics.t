use strict;
use warnings;

use Test::More;

# ABSTRACT: Test basic functionality

use Test::DZil qw( simple_ini );
use lib 't/lib';
use tester;

sub fatal(&) {
    local $@;
    my $ok = eval { $_[0]->(); 1 };
    ( $ok, $@ );
}

my $test_1 = tester->new();

SKIP: {
    note "Generating Initial Yaml File";
    $test_1->add(
        'dist.ini' => simple_ini(
            [ 'GatherDir' => { include_dotfiles => 1 }, ],
            [ 'TravisCI'  => {}, ],
        )
    );

    my ( $ok, $error ) = fatal { $test_1->builder->build };
    ok( $ok, "Build OK" ) or do {
        diag explain $error;
        skip "Build did not pass", 3;
    };

    my $gen_yaml = $test_1->sourcedir->child('.travis.yml');

    ok( $gen_yaml->exists, '.travis.yml added' );
    ok( !$test_1->builddir->child('.travis.yml')->exists,
        '.travis.yml not added to build dir' );
    cmp_ok( [ $gen_yaml->lines_utf8( { chomp => 1 } ) ]->[0],
        qw[eq], '---', 'Looks like a valid YAML file' );
}

my $test_2 = tester->new( tempdir => $test_1->sourcedir );

SKIP: {
    note "Simulated rebuild on a dir with exisiting .yml file";

    my ( $ok, $error ) = fatal { $test_2->builder->build };
    ok( $ok, "Build OK" ) or do {
        diag explain $error;
        skip "Build did not pass", 3;
    };

    my $gen_yaml = $test_2->sourcedir->child('.travis.yml');
    ok( $gen_yaml->exists, '.travis.yml in second generation' );
    ok( $test_2->builddir->child('.travis.yml')->exists,
            '.travis.yml in second generation build dir '
          . '( due to gatherdir + dotfiles )' );

    cmp_ok( [ $gen_yaml->lines_utf8( { chomp => 1 } ) ]->[0],
        qw[eq], '---', 'Looks like a valid YAML file' );
}
done_testing;

