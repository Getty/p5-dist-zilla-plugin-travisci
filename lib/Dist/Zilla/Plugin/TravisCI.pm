package Dist::Zilla::Plugin::TravisCI;
# ABSTRACT: Integrating the generation of .travis.yml into your dzil

use Moose;

use Dist::Zilla::File::InMemory;

with 'Dist::Zilla::Role::InstallTool';

our @phases = ( ( map { my $phase = $_; ('before_'.$phase, $phase, 'after_'.$phase) } qw( install script ) ), 'after_success', 'after_failure' );
our @emptymvarrayattr = qw( notify_email notify_irc requires env script_env extra_dep );

has $_ => ( is => 'ro', isa => 'ArrayRef[Str]', default => sub { [] } ) for (@phases, @emptymvarrayattr);

our @bools = qw( verbose test_deps no_notify_email coveralls );

has $_ => ( is => 'ro', isa => 'Bool', default => sub { 0 } ) for @bools;

has irc_template  => ( is => 'ro', isa => 'ArrayRef[Str]', default => sub { [
   "%{branch}#%{build_number} by %{author}: %{message} (%{build_url})",
] } );

has perl_version  => ( is => 'ro', isa => 'ArrayRef[Str]', default => sub { [
   "5.18",
   "5.16",
   "5.14",
   "5.12",
   "5.10",
] } );

our @core_env = ("HARNESS_OPTIONS=j10:c HARNESS_TIMER=1");

around mvp_multivalue_args => sub {
	my ($orig, $self) = @_;

	my @start = $self->$orig;
	return @start, @phases, @emptymvarrayattr, qw( irc_template perl_version );
};

sub setup_installer {
   my $self = shift;
   $self->build_travis_yml;
}

sub _get_exports { shift; map { "export ".$_ } @_ }

sub build_travis_yml {
	my ($self, $is_build_branch) = @_;

	require YAML;

	my $zilla = $self->zilla;
	my %travisyml = ( language => "perl", perl => $self->perl_version );
	my $rmeta = $zilla->distmeta->{resources};

	my %notifications;

	my @emails = grep { $_ } @{$self->notify_email};
	if ($self->no_notify_email) {
		$notifications{email} = \"false";
	} elsif (scalar @emails) {
		$notifications{email} = \@emails;
	}

	if (%notifications) {
		$travisyml{notifications} = \%notifications;
	}

	my %phases_commands = map { $_ => $self->$_ } @phases;

	my $verbose = $self->verbose ? ' --verbose ' : ' --quiet ';

	unshift @{$phases_commands{before_install}}, (
		'git config --global user.name "Dist Zilla Plugin TravisCI"',
		'git config --global user.email $HOSTNAME":not-for-mail@travis-ci.org"',
	);

	my @extra_deps = @{$self->extra_dep};

	my $needs_cover;

	if ($self->coveralls) {
		push @extra_deps, 'Devel::Cover::Report::Coveralls';
		unshift @{$phases_commands{after_success}}, 'cover -report coveralls';
		$needs_cover = 1;
	}

	if ($needs_cover) {
		push @{$self->env}, 'HARNESS_PERL_SWITCHES=-MDevel::Cover=-db,$TRAVIS_BUILD_DIR/cover_db';
	}

	my @env_exports = $self->_get_exports(@core_env, @{$self->env});

	unless (@{$phases_commands{install}}) {
		push @{$phases_commands{install}}, (
			"cpanm ".$verbose." --notest --skip-installed Dist::Zilla App::CPAN::Fresh",
			"dzil authordeps | grep -ve '^\\W' | xargs -n 5 -P 10 cpanf",
			"dzil listdeps | grep -ve '^\\W' | cpanm ".$verbose." ".($self->test_deps ? "" : " --notest ")." --skip-installed",
		);
		if (@extra_deps) {
			push @{$phases_commands{install}}, (
				"cpanm ".$verbose." ".($self->test_deps ? "" : " --notest ")." ".join(" ",@extra_deps),
			);
		}
	}

	unless (@{$phases_commands{script}}) {
		push @{$phases_commands{script}}, "dzil smoke --release --author";
	}

	unshift @{$phases_commands{script}}, $self->_get_exports(@{$self->script_env});

	unless (@{$phases_commands{install}}) {
		$phases_commands{install} = [
			'cpanm --installdeps '.$verbose.' '.($self->test_deps ? "" : "--notest").' --skip-installed .',
		];
	}

	if (@{$self->requires}) {
		unshift @{$phases_commands{before_install}}, "sudo apt-get install -qq ".join(" ",@{$self->requires});
	}

	unshift @{$phases_commands{before_install}}, (
		'rm .travis.yml',
	);

	push @{$phases_commands{install}}, @{delete $phases_commands{after_install}};

	unshift @{$phases_commands{script}}, $self->_get_exports(@{$self->script_env});

	my $first = 0;
	for (@phases) {
		next unless defined $phases_commands{$_};
		my @commands = @{$phases_commands{$_}};
		if (@commands) {
			$travisyml{$_} = [
				$first
					? ()
					: (@env_exports),
				@commands,
			];
			$first = 1;
		}
	}

	YAML::DumpFile($zilla->root->file('.travis.yml')->stringify, \%travisyml);

}


__PACKAGE__->meta->make_immutable;

1;


=head1 SYNOPSIS

  [TravisCI]
  perl_version = 5.10
  perl_version = 5.12
  perl_version = 5.14
  perl_version = 5.16
  notify_email = other@email.then.default
  irc_template = %{branch}#%{build_number} by %{author}: %{message} (%{build_url})
  requires = libdebian-package-dev
  extra_dep = Extra::Module
  env = KEY=VALUE
  script_env = SCRIPTKEY=SCRIPTONLY
  before_install = echo "After the installation of requirements before perl modules"
  install = echo "Replace our procedure to install the perl modules"
  after_install = echo "In the install phase after perl modules are installed"
  before_script = echo "Do something before the dzil smoke is called"
  script = echo "replace our call for dzil smoke"
  after_script = echo "another test script to run, probably?"
  after_success = echo "yeah!"
  after_failure = echo "Buh!! :("
  verbose = 0
  test_deps = 0
  test_authordeps = 0
  no_notify_email = 0
  coveralls = 0

=head1 DESCRIPTION

Adds a B<.travis.yml> to your repository on B<build> or B<release>. This is a
very early release, more features are planned and upcoming, including more
documentation :).

=head1 BASED ON

This plugin is based on code of L<Dist::Zilla::TravisCI>.

=head1 SUPPORT

IRC

  Join #distzilla on irc.perl.org. Highlight Getty for fast reaction :).

Repository

  http://github.com/Getty/p5-dist-zilla-plugin-travisci
  Pull request and additional contributors are welcome
 
Issue Tracker

  http://github.com/Getty/p5-dist-zilla-plugin-travisci/issues
