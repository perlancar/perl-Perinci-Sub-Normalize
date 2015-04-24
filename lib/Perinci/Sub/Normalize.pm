package Perinci::Sub::Normalize;

# DATE
# VERSION

use 5.010001;
use strict;
use warnings;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(
                       normalize_function_metadata
               );

use Sah::Schema::Rinci;
my $sch = $Sah::Schema::Rinci::SCHEMAS{rinci_function}
    or die "BUG: Rinci schema structure changed (1)";
my $sch_proplist = $sch->[1]{_prop}
    or die "BUG: Rinci schema structure changed (2)";

sub _normalize{
    my ($meta, $ver, $opts, $proplist, $nmeta, $prefix, $modprefix) = @_;

    my $opt_aup = $opts->{allow_unknown_properties};
    my $opt_nss = $opts->{normalize_sah_schemas};
    my $opt_rip = $opts->{remove_internal_properties};

    if (defined $ver) {
        defined($meta->{v}) && $meta->{v} eq $ver
            or die "$prefix: Metadata version must be $ver";
    }

  KEY:
    for my $k (keys %$meta) {

        # strip attributes prefixed with _ (e.g. args._comment)
        if ($k =~ /\.(\w+)\z/) {
            my $attr = $1;
            unless ($attr =~ /\A_/ && $opt_rip) {
                $nmeta->{$k} = $meta->{$k};
            }
            next KEY;
        }

        # skip properties prefixed with _ (e.g. _comment)
        my $prop = $k;
        my $prop_proplist = $proplist->{$prop};
        if ($prop =~ /\A_/) {
            unless ($opt_rip) {
                $nmeta->{$prop} = $meta->{$k};
            }
            next KEY;
        }

        # normalize prop(LANG) to prop.alt.lang.LANG
        if ($prop =~ /\A(.+)\((\w+)\)\z/) {
            $nmeta->{"$1.alt.lang.$2"} = $meta->{$k};
            next KEY;
        }

        # try to load module that declare new props first
        if (!$opt_aup && !$prop_proplist) {
            if ($prop =~ /\A[A-Za-z][A-Za-z0-9_]*\z/) {
                $modprefix //= $prefix;
                my $mod = "Perinci/Sub/Property$modprefix/$prop.pm";
                eval { require $mod };
                # hide technical error message from require()
                if ($@) {
                    die "Unknown property '$prefix/$prop' (and couldn't ".
                        "load property module '$mod'): $@" if $@;
                }
                $prop_proplist = $proplist->{$prop};
            }
            die "Unknown property '$prefix/$prop'"
                unless $prop_proplist;
        }
        if ($prop_proplist && $prop_proplist->{_prop}) {
            die "Property '$prefix/$prop' must be a hash"
                unless ref($meta->{$k}) eq 'HASH';
            $nmeta->{$k} = {};
            _normalize(
                $meta->{$k},
                $prop_proplist->{_ver},
                $opts,
                $prop_proplist->{_prop},
                $nmeta->{$k},
                "$prefix/$prop",
            );
        } elsif ($prop_proplist && $prop_proplist->{_elem_prop}) {
            die "Property '$prefix/$prop' must be an array"
                unless ref($meta->{$k}) eq 'ARRAY';
            $nmeta->{$k} = [];
            my $i = 0;
            for (@{ $meta->{$k} }) {
                my $href = {};
                if (ref($_) eq 'HASH') {
                    _normalize(
                        $_,
                        $prop_proplist->{_ver},
                        $opts,
                        $prop_proplist->{_elem_prop},
                        $href,
                        "$prefix/$prop/$i",
                    );
                    push @{ $nmeta->{$k} }, $href;
                } else {
                    push @{ $nmeta->{$k} }, $_;
                }
                $i++;
            }
        } elsif ($prop_proplist && $prop_proplist->{_value_prop}) {
            die "Property '$prefix/$prop' must be a hash"
                unless ref($meta->{$k}) eq 'HASH';
            $nmeta->{$k} = {};
            for (keys %{ $meta->{$k} }) {
                $nmeta->{$k}{$_} = {};
                die "Property '$prefix/$prop/$_' must be a hash"
                    unless ref($meta->{$k}{$_}) eq 'HASH';
                _normalize(
                    $meta->{$k}{$_},
                    $prop_proplist->{_ver},
                    $opts,
                    $prop_proplist->{_value_prop},
                    $nmeta->{$k}{$_},
                    "$prefix/$prop/$_",
                    ($prop eq 'args' ? "$prefix/arg" : undef),
                );
            }
        } else {
            if ($k eq 'schema' && $opt_nss) { # XXX currently hardcoded
                require Data::Sah::Normalize;
                $nmeta->{$k} = Data::Sah::Normalize::normalize_schema(
                    $meta->{$k});
            } else {
                $nmeta->{$k} = $meta->{$k};
            }
        }
    }

    $nmeta;
}

sub normalize_function_metadata($;$) {
    my ($meta, $opts) = @_;

    $opts //= {};

    $opts->{allow_unknown_properties}    //= 0;
    $opts->{normalize_sah_schemas}       //= 1;
    $opts->{remove_internal_properties}  //= 0;

    _normalize($meta, 1.1, $opts, $sch_proplist, {}, '');
}

1;
# ABSTRACT: Normalize Rinci function metadata

=head1 SYNOPSIS

 use Perinci::Sub::Normalize qw(normalize_function_metadata);

 my $nmeta = normalize_function_metadata($meta);


=head1 FUNCTIONS

=head2 normalize_function_metadata($meta, \%opts) => HASH

Normalize and check L<Rinci> function metadata C<$meta>. Return normalized
metadata, which is a shallow copy of C<$meta>. Die on error.

Available options:

=over

=item * allow_unknown_properties => BOOL (default: 0)

If set to true, will die if there are unknown properties.

=item * normalize_sah_schemas => BOOL (default: 1)

By default, L<Sah> schemas e.g. in C<result/schema> or C<args/*/schema> property
is normalized using L<Data::Sah>'s C<normalize_schema>. Set this to 0 if you
don't want this.

=item * remove_internal_properties => BOOL (default: 0)

If set to 1, all properties and attributes starting with underscore (C<_>) with
will be stripped. According to L<DefHash> specification, they are ignored and
usually contain notes/comments/extra information.

=back


=head1 SEE ALSO

L<Rinci::function>

=cut
