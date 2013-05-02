package Dist::Zilla::Plugin::TravisCI;
# ABSTRACT: Integrating the generation of .travis.yml into your dzil

use Moose;

use Dist::Zilla::File::InMemory;

with 'Dist::Zilla::Role::InstallTool';

use File::Slurp;
use YAML qw( DumpFile );
use Path::Class;

our @phases = ( ( map { my $phase = $_; ('before_'.$phase, $phase, 'after_'.$phase) } qw( install script ) ), 'after_success', 'after_failure', 'with_script' );
our @emptymvarrayattr = qw( notify_email notify_irc requires base_env script_env );

has $_ => ( is => 'ro', isa => 'ArrayRef[Str]', default => sub { [] } ) for (@phases, @emptymvarrayattr);

our @bools = qw( verbose test_deps test_authordeps no_notify_email );

has $_ => ( is => 'ro', isa => 'Bool', default => sub { 0 } ) for @bools;

has irc_template  => ( is => 'ro', isa => 'ArrayRef[Str]', default => sub { [
   "%{branch}#%{build_number} by %{author}: %{message} (%{build_url})",
] } );

has perl_version  => ( is => 'ro', isa => 'ArrayRef[Str]', default => sub { [
   "5.16",
   "5.14",
   "5.12",
   "5.10",
] } );

our @core_env = ("AUTOMATED_TESTING=1 HARNESS_OPTIONS=j10:c HARNESS_TIMER=1");

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

	my @env_exports = $self->_get_exports(@core_env, @{$self->base_env});

	my %phases_commands = map { $_ => $self->$_ } @phases;

	my $verbose = $self->verbose ? ' --verbose ' : ' --quiet ';

	unshift @{$phases_commands{before_install}}, (
		'git config --global user.name "Dist Zilla Plugin TravisCI"',
		'git config --global user.email $HOSTNAME":not-for-mail@travis-ci.org"',
	);

	unless (@{$phases_commands{install}}) {
		push @{$phases_commands{install}}, (
			"cpanm ".$verbose." --notest --skip-satisfied Dist::Zilla",
			"dzil authordeps | grep -vP '[^\\w:]' | xargs -n 5 -P 10 cpanm ".$verbose." ".($self->test_authordeps ? "" : " --notest ")." --skip-satisfied",
			"dzil listdeps | grep -vP '[^\\w:]' | cpanm ".$verbose." ".($self->test_deps ? "" : " --notest ")." --skip-satisfied",
		);
	}

	unless (@{$phases_commands{script}}) {
		push @{$phases_commands{script}}, "dzil smoke --release --author";
	}

	unshift @{$phases_commands{script}}, $self->_get_exports(@{$self->script_env});

	unless (@{$phases_commands{install}}) {
		$phases_commands{install} = [
			'cpanm --installdeps '.$verbose.' '.($self->test_deps ? "" : "--notest").' --skip-satisfied .',
		];
	}

	if (@{$self->requires}) {
		unshift @{$phases_commands{before_install}}, "sudo apt-get install -qq ".join(" ",@{$self->requires});
	}

	unshift @{$phases_commands{before_install}}, (
		'rm .travis.yml',
	);

	push @{$phases_commands{install}}, @{delete $phases_commands{after_install}};

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

	DumpFile(Path::Class::File->new($zilla->built_in, '.travis.yml')->stringify, \%travisyml);

}


__PACKAGE__->meta->make_immutable;

1;

=head1 BASED ON

  Based on code from L<Dist::Zilla::TravisCI>.

=cut
