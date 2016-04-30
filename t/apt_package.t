use strict;
use warnings;
use Test::More;
use Test::DZil;
use YAML;

subtest 'apt_package option' => sub {
	my $packages = [ 'libzmq-dev' ];
	my $tzil = create_tzil({
		apt_package => $packages,
	});
	$tzil->build();
	my $travis_yml = YAML::Load($tzil->slurp_file('source/.travis.yml'));
	is_deeply(
		$travis_yml->{addons},
		{ apt_packages => $packages },
		'addons.apt_packages configured with package'
	);

	push @{$packages}, 'libzmq1';
	$tzil = create_tzil({
		apt_package => $packages,
	});
	$tzil->build();
	$travis_yml = YAML::Load($tzil->slurp_file('source/.travis.yml'));
	is_deeply(
		$travis_yml->{addons},
		{ apt_packages => $packages },
		'addons.apt_packages configured with both packages'
	);
};

sub create_tzil {
	my ($travis_ci_config) = @_;
	return Builder->from_config(
		{ dist_root => 't/corpus' },
		{
			add_files => {
				'source/dist.ini' => simple_ini([
					TravisCI => $travis_ci_config,
				])
			}
		}
	);
}

done_testing;
