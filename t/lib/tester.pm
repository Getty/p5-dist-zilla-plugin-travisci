use 5.006;    # our
use strict;
use warnings;

package tester;

# ABSTRACT: minitester thing for TravisCI

use Test::DZil qw( Builder );
use Path::Tiny qw( path );
use Test::TempDir::Tiny qw();
use Test::More import => [qw( note explain )];

# ->new( %opts ) => Object
# ->new( { opts } ) => Object
sub new { return bless { ref $_[1] ? %{ $_[1] } : splice @_, 1 }, $_[0] }

# ->tempdir() => Temp Path String
sub tempdir {
    return $_[0]->{tempdir} if exists $_[0]->{tempdir};
    return ( $_[0]->{tempdir} =
          Test::TempDir::Tiny::tempdir( $_[0]->{name} ? $_[0]->{name} : () ) );
}

# ->add( $path, $text_content )
sub add {
    path( $_[0]->tempdir, $_[1] )->parent->mkpath;
    path( $_[0]->tempdir, $_[1] )->spew_utf8( $_[2] );
}

# ->builder() => Builder Object
sub builder {
    my $self = shift;
    return $self->{builder} if exists $self->{builder};
    $self->{builder} =
      Builder->from_config( { dist_root => q[] . $self->tempdir, @_ } );
    $self->{builder}->chrome->logger->set_debug(1);
    $self->{builder};
}

# ->builddir() => Path Object
sub builddir {
    return path( $_[0]->builder->tempdir, 'build' );
}

# ->sourcedir() => Path Object
sub sourcedir {
    return path( $_[0]->builder->tempdir, 'source' );
}

# ->auto_note_stuff()
sub auto_note_stuff {
    note explain $_[0]->builder->log_events;
    note explain $_[0]->builder->distmeta;
    note $_ for $_[0]->sourcedir->children();
    note $_ for $_[0]->builddir->children();

}

1;

