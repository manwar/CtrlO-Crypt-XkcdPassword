package CtrlO::Crypt::XkcdPassword;
use strict;
use warnings;

# ABSTRACT: Yet another XKCD style password generator

our $VERSION = '0.900';

use Carp qw(croak);
use Crypt::Rijndael;
use Crypt::URandom;
use Data::Entropy qw(with_entropy_source);
use Data::Entropy::Algorithms qw(rand_int pick_r shuffle_r choose_r);
use Data::Entropy::RawSource::CryptCounter;
use Data::Entropy::Source;

use base 'Class::Accessor::Fast';

__PACKAGE__->mk_accessors(qw(entropy wordlist _list));

=method new

  my $pw_generator = CtrlO::Crypt::XkcdPassword->new;

  my $pw_generator = CtrlO::Crypt::XkcdPassword->new({
      wordlist => '/path/to/file'
  });

  my $pw_generator = CtrlO::Crypt::XkcdPassword->new({
      wordlist => 'CtrlO::Crypt::XkcdPassword::Wordlist'
  });

  my $pw_generator = CtrlO::Crypt::XkcdPassword->new({
      entropy => Data::Entropy::Source->new( ... )
  });

Initialize a new object. Uses C<CtrlO::Crypt::XkcdPassword::Wordlist>
as a word list per default. The default entropy is based on
C<Crypt::URandom>, i.e. '/dev/urandom' and should be random enough (at
least more random than plain old C<rand()>).

If you want / need to supply another source of entropy, you can do so
by setting up an instance of C<Data::Entropy::Source> and passing it
to C<new> as C<entropy>.

=cut

sub new {
    my ( $class, $args ) = @_;

    my %object;

    # init the wordlist
    $object{wordlist} =
        $args->{wordlist} || 'CtrlO::Crypt::XkcdPassword::Wordlist';
    if ( $object{wordlist} =~ /::/ ) {

        # TODO
        $object{_list} = [qw(correct horse battery staple)];
    }
    elsif ( -r $object{wordlist} ) {
        my @list = do { local (@ARGV) = $object{wordlist}; <> };
        chomp(@list);
        $object{_list} = \@list;
    }
    else {
        croak(    'Invalid wordlist: >'
                . $object{wordlist}
                . '<. Has to be either a Perl module or a file' );
    }

    # poor person's lazy_build
    $object{entropy} = $args->{entropy} || $class->_build_entropy;

    return bless \%object, $class;
}

sub _build_entropy {
    my $class = shift;
    return Data::Entropy::Source->new(
        Data::Entropy::RawSource::CryptCounter->new(
            Crypt::Rijndael->new( Crypt::URandom::urandom(32) )
        ),
        "getc"
    );
}

=method xkcd

  my $pw = $pw_generator->xkcd;
  my $pw = $pw_generator->xkcd({ words  => 3 });
  my $pw = $pw_generator->xkcd({ digits => 2 });

Generate a random, XKCD-style password (actually a passphrase, but
we're all trying to getting things done, so who cares..)

Per default will return 4 randomly chosen words from the word list,
each word's first letter turned to upper case, and concatenated
together into one string:

  $pw_generator->xkcd;
  # CorrectHorseBatteryStaple

You can get a different number of words by passing in C<words>. But
remember that anything smaller than 3 will probably make for rather
poor passwords, and anything bigger than 7 will be hard to remember.

You can also pass in C<digits> to append a random number consisting of
C<digits> digits to the password:

  $pw_generator->xkcd({ words => 3, digits => 2 });
  # StapleBatteryCorrect75

=cut

sub xkcd {
    my ( $self, $args ) = @_;
    my $word_count = $args->{words} || 4;

    my $words = with_entropy_source(
        $self->entropy,
        sub {
            shuffle_r( choose_r( $word_count, $self->_list ) );
        }
    );

    if ( my $d = $args->{digits} ) {
        push(
            @$words,
            sprintf(
                '%0' . $d . 'd',
                with_entropy_source(
                    $self->entropy, sub { rand_int( 10 ** $d ) }
                )
            )
        );
    }

    return join( '', map {ucfirst} @$words );
}

1;

__END__

=head1 SYNOPSIS

  use CtrlO::Crypt::XkcdPassword;
  my $password_generator = CtrlO::Crypt::XkcdPassword->new;

  say $password_generator->xkcd;
  # LameSeaweedsLavaHeal

  say $password_generator->xkcd({ words => 3 });
  # TightLarkSpell

  say $password_generator->xkcd({ words => 3, digits => 3 });
  # WasteRoommateLugged220

  # Use custom word list
  CtrlO::Crypt::XkcdPassword->new({
    wordlist => '/path/to/wordlist'
  });
  CtrlO::Crypt::XkcdPassword->new({
    wordlist => 'Some::Wordlist::From::CPAN' # but there is no unified API for wordlist modules...
  });

  # Use another source of randomness (aka entropy)
  CtrlO::Crypt::XkcdPassword->new({
    entropy => Data::Entropy::Source->new( ... );
  });

=head1 DESCRIPTION

C<CtrlO::Crypt::XkcdPassword> generates a random password using the
algorithm suggested in L<https://xkcd.com/936/>: It selects 4 words
from a curated list of words and combines them into a hopefully easy
to remember password.

But L<https://xkcd.com/927/> also applies to this module, as there are
already a lot of modules on CPAN also implementing
L<https://xkcd.com/936/>. We still wrote a new one, mainly because we
wanted to use a strong source of entropy.

=head1 RUNNING FROM GIT

This is B<not> the recommended way to install / use this module. But
it's handy if you want to submit a patch or play around with the code
prior to a proper installation.

=head2 Carton

  git clone git@github.com:domm/CtrlO-Crypt-XkcdPassword.git
  carton install
  carton exec perl -Ilib -MCtrlO::Crypt::XkcdPassword -E 'say CtrlO::Crypt::XkcdPassword->new->xkcd'

=head2 cpanm & local::lib

  git clone git@github.com:domm/CtrlO-Crypt-XkcdPassword.git
  cpanm -L local --installdeps .
  perl -Mlocal::lib=local -Ilib -MCtrlO::Crypt::XkcdPassword -E 'say CtrlO::Crypt::XkcdPassword->new->xkcd'

=head1 SEE ALSO

Inspired by L<https://xkcd.com/936/> and L<https://xkcd.com/927/>

There are a lot of similar modules on CPAN, so I just point you to
L<Neil Bower's comparison of CPAN modules for generating passwords|http://neilb.org/reviews/passwords.html>

I leanrned the usage of C<Data::Entropy> is from
L<https://metacpan.org/pod/Crypt::Diceware>, which also implements an
algorithm to generate a random passphrase.

=head1 THANKS

Thanks to L<CTRL-O|http://www.ctrlo.com/> for funding the development of this module.


