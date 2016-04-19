use strict;
use warnings;

use Test::More;

# ABSTRACT: Test augmentation via a script

use Test::DZil qw( simple_ini );
use lib 't/lib';
use tester;
use YAML qw();

sub fatal(&) {
    local $@;
    my $ok = eval { $_[0]->(); 1 };
    ( $ok, $@ );
}

SKIP: {
    my $test_1 = tester->new();
    $test_1->add(
        'dist.ini' => simple_ini(
            [ 'GatherDir' => { include_dotfiles => 1 }, ],
            [
                'TravisCI' =>
                  { 'modifier_script' => 'travisci_customizations.pl' },
            ],
        )
    );
    $test_1->add( 'travisci_customizations.pl' => <<'EOF');
use strict;
use warnings;
sub {
  my ( $code ) = @_;
  $code->{'this_key_is_bogus'} = 'a value';
};
EOF

    my ( $ok, $error ) = fatal { $test_1->builder->build };
    ok( $ok, "Build OK" ) or do {
        diag explain $error;
        skip "Build did not pass", 3;
    };

    my $gen_yaml = $test_1->sourcedir->child('.travis.yml');

    ok( $gen_yaml->exists, '.travis.yml added' );

    my $content = YAML::Load( $gen_yaml->slurp_utf8 );
    ok( exists $content->{this_key_is_bogus}, 'Modified key emitted' );
    cmp_ok( $content->{this_key_is_bogus},
        'eq', 'a value', 'Modified key has expected value' );
}

done_testing;

